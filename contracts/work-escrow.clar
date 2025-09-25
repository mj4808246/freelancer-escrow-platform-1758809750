;; work-escrow
;; Manage project milestones, payments, and dispute resolution for freelance work

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u2001))
(define-constant ERR-PROJECT-NOT-FOUND (err u2002))
(define-constant ERR-INVALID-MILESTONE (err u2003))
(define-constant ERR-MILESTONE-COMPLETED (err u2004))
(define-constant ERR-INSUFFICIENT-FUNDS (err u2005))
(define-constant ERR-ALREADY-ASSIGNED (err u2006))
(define-constant ERR-PROJECT-COMPLETED (err u2007))
(define-constant ERR-INVALID-STATUS (err u2008))
(define-constant ERR-DEADLINE-PASSED (err u2009))
(define-constant ERR-PAYMENT-FAILED (err u2010))
(define-constant ERR-DISPUTE-ACTIVE (err u2011))
(define-constant PLATFORM-FEE-RATE u250) ;; 2.5% platform fee

;; data vars
(define-data-var next-project-id uint u1)
(define-data-var platform-treasury principal tx-sender)
(define-data-var total-projects-created uint u0)
(define-data-var total-funds-escrowed uint u0)

;; Project structure
(define-map projects
  uint ;; project-id
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    client: principal,
    freelancer: (optional principal),
    total-budget: uint,
    funds-deposited: uint,
    status: (string-ascii 20), ;; "open", "assigned", "active", "completed", "disputed", "cancelled"
    deadline: uint,
    created-at: uint,
    completed-at: (optional uint),
    total-milestones: uint,
    completed-milestones: uint
  }
)

;; Milestone structure
(define-map milestones
  { project-id: uint, milestone-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 300),
    payment-amount: uint,
    status: (string-ascii 20), ;; "pending", "submitted", "approved", "paid", "disputed"
    deadline: uint,
    submitted-at: (optional uint),
    approved-at: (optional uint),
    paid-at: (optional uint),
    deliverable-hash: (optional (buff 32))
  }
)

;; Track milestone count per project
(define-map project-milestone-count
  uint ;; project-id
  uint ;; milestone-count
)

;; Freelancer profiles and ratings
(define-map freelancer-profiles
  principal ;; freelancer
  {
    total-projects: uint,
    completed-projects: uint,
    total-earned: uint,
    average-rating: uint,
    rating-count: uint,
    is-active: bool
  }
)

;; Client profiles and ratings  
(define-map client-profiles
  principal ;; client
  {
    total-projects: uint,
    completed-projects: uint,
    total-spent: uint,
    average-rating: uint,
    rating-count: uint,
    is-active: bool
  }
)

;; Project ratings
(define-map project-ratings
  { project-id: uint, rater: principal }
  {
    rating: uint, ;; 1-5 scale
    feedback: (string-ascii 200),
    rated-at: uint
  }
)

;; Dispute management
(define-map disputes
  uint ;; project-id
  {
    milestone-id: uint,
    raised-by: principal,
    reason: (string-ascii 300),
    status: (string-ascii 20), ;; "open", "investigating", "resolved", "closed"
    resolution: (optional (string-ascii 200)),
    created-at: uint,
    resolved-at: (optional uint)
  }
)

;; Project applications/bids
(define-map project-applications
  { project-id: uint, freelancer: principal }
  {
    proposed-budget: uint,
    proposed-timeline: uint,
    cover-letter: (string-ascii 300),
    applied-at: uint,
    status: (string-ascii 20) ;; "pending", "accepted", "rejected"
  }
)

;; private functions
(define-private (is-project-client (project-id uint) (user principal))
  (match (map-get? projects project-id)
    project (is-eq user (get client project))
    false
  )
)

(define-private (is-project-freelancer (project-id uint) (user principal))
  (match (map-get? projects project-id)
    project
    (match (get freelancer project)
      freelancer-principal (is-eq user freelancer-principal)
      false
    )
    false
  )
)

(define-private (is-project-participant (project-id uint) (user principal))
  (or
    (is-project-client project-id user)
    (is-project-freelancer project-id user)
  )
)

(define-private (calculate-platform-fee (amount uint))
  (/ (* amount PLATFORM-FEE-RATE) u10000)
)

(define-private (update-freelancer-stats (freelancer principal) (earned uint))
  (let
    (
      (current-profile (default-to 
        { total-projects: u0, completed-projects: u0, total-earned: u0, average-rating: u0, rating-count: u0, is-active: true }
        (map-get? freelancer-profiles freelancer)
      ))
    )
    (map-set freelancer-profiles freelancer
      (merge current-profile
        {
          completed-projects: (+ (get completed-projects current-profile) u1),
          total-earned: (+ (get total-earned current-profile) earned)
        }
      )
    )
  )
)

(define-private (update-client-stats (client principal) (spent uint))
  (let
    (
      (current-profile (default-to 
        { total-projects: u0, completed-projects: u0, total-spent: u0, average-rating: u0, rating-count: u0, is-active: true }
        (map-get? client-profiles client)
      ))
    )
    (map-set client-profiles client
      (merge current-profile
        {
          completed-projects: (+ (get completed-projects current-profile) u1),
          total-spent: (+ (get total-spent current-profile) spent)
        }
      )
    )
  )
)

;; public functions

;; Create a new project
(define-public (create-project (title (string-ascii 100)) (description (string-ascii 500)) (total-budget uint) (deadline uint))
  (let
    (
      (project-id (var-get next-project-id))
      (current-block burn-block-height)
    )
    (asserts! (> total-budget u0) ERR-INSUFFICIENT-FUNDS)
    (asserts! (> deadline current-block) ERR-DEADLINE-PASSED)
    
    (map-set projects project-id
      {
        title: title,
        description: description,
        client: tx-sender,
        freelancer: none,
        total-budget: total-budget,
        funds-deposited: u0,
        status: "open",
        deadline: deadline,
        created-at: current-block,
        completed-at: none,
        total-milestones: u0,
        completed-milestones: u0
      }
    )
    
    (map-set project-milestone-count project-id u0)
    (var-set next-project-id (+ project-id u1))
    (var-set total-projects-created (+ (var-get total-projects-created) u1))
    
    ;; Update client stats
    (let
      (
        (current-profile (default-to 
          { total-projects: u0, completed-projects: u0, total-spent: u0, average-rating: u0, rating-count: u0, is-active: true }
          (map-get? client-profiles tx-sender)
        ))
      )
      (map-set client-profiles tx-sender
        (merge current-profile { total-projects: (+ (get total-projects current-profile) u1) })
      )
    )
    
    (ok project-id)
  )
)

;; Add milestone to project
(define-public (add-milestone (project-id uint) (title (string-ascii 100)) (description (string-ascii 300)) (payment-amount uint) (deadline uint))
  (let
    (
      (milestone-count (default-to u0 (map-get? project-milestone-count project-id)))
      (new-milestone-id (+ milestone-count u1))
      (project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND))
    )
    (asserts! (is-project-client project-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> payment-amount u0) ERR-INSUFFICIENT-FUNDS)
    (asserts! (is-eq (get status project) "open") ERR-INVALID-STATUS)
    
    (map-set milestones
      { project-id: project-id, milestone-id: new-milestone-id }
      {
        title: title,
        description: description,
        payment-amount: payment-amount,
        status: "pending",
        deadline: deadline,
        submitted-at: none,
        approved-at: none,
        paid-at: none,
        deliverable-hash: none
      }
    )
    
    ;; Update project milestone count
    (map-set project-milestone-count project-id new-milestone-id)
    (map-set projects project-id
      (merge project { total-milestones: new-milestone-id })
    )
    
    (ok new-milestone-id)
  )
)

;; Deposit funds for project
(define-public (deposit-funds (project-id uint) (amount uint))
  (let ((project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND)))
    (asserts! (is-project-client project-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer funds to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update project funds
    (map-set projects project-id
      (merge project
        { funds-deposited: (+ (get funds-deposited project) amount) }
      )
    )
    
    (var-set total-funds-escrowed (+ (var-get total-funds-escrowed) amount))
    (ok amount)
  )
)

;; Apply for project
(define-public (apply-for-project (project-id uint) (proposed-budget uint) (proposed-timeline uint) (cover-letter (string-ascii 300)))
  (let ((project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND)))
    (asserts! (is-eq (get status project) "open") ERR-INVALID-STATUS)
    (asserts! (not (is-project-client project-id tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (> proposed-budget u0) ERR-INSUFFICIENT-FUNDS)
    
    (map-set project-applications
      { project-id: project-id, freelancer: tx-sender }
      {
        proposed-budget: proposed-budget,
        proposed-timeline: proposed-timeline,
        cover-letter: cover-letter,
        applied-at: burn-block-height,
        status: "pending"
      }
    )
    
    (ok true)
  )
)

;; Assign project to freelancer
(define-public (assign-project (project-id uint) (freelancer principal))
  (let ((project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND)))
    (asserts! (is-project-client project-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status project) "open") ERR-INVALID-STATUS)
    
    (map-set projects project-id
      (merge project
        {
          freelancer: (some freelancer),
          status: "assigned"
        }
      )
    )
    
    ;; Update application status
    (map-set project-applications
      { project-id: project-id, freelancer: freelancer }
      (merge
        (default-to 
          { proposed-budget: u0, proposed-timeline: u0, cover-letter: "", applied-at: u0, status: "pending" }
          (map-get? project-applications { project-id: project-id, freelancer: freelancer })
        )
        { status: "accepted" }
      )
    )
    
    (ok freelancer)
  )
)

;; Start project work
(define-public (start-project (project-id uint))
  (let ((project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND)))
    (asserts! (is-project-freelancer project-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status project) "assigned") ERR-INVALID-STATUS)
    
    (map-set projects project-id
      (merge project { status: "active" })
    )
    
    (ok true)
  )
)

;; Submit milestone deliverable
(define-public (submit-milestone (project-id uint) (milestone-id uint) (deliverable-hash (buff 32)))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND))
      (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) ERR-INVALID-MILESTONE))
    )
    (asserts! (is-project-freelancer project-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status milestone) "pending") ERR-MILESTONE-COMPLETED)
    (asserts! (is-eq (get status project) "active") ERR-INVALID-STATUS)
    
    (map-set milestones
      { project-id: project-id, milestone-id: milestone-id }
      (merge milestone
        {
          status: "submitted",
          submitted-at: (some burn-block-height),
          deliverable-hash: (some deliverable-hash)
        }
      )
    )
    
    (ok true)
  )
)

;; Approve milestone and release payment
(define-public (approve-milestone (project-id uint) (milestone-id uint))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND))
      (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) ERR-INVALID-MILESTONE))
      (payment-amount (get payment-amount milestone))
      (platform-fee (calculate-platform-fee payment-amount))
      (net-payment (- payment-amount platform-fee))
      (freelancer (unwrap! (get freelancer project) ERR-NOT-AUTHORIZED))
    )
    (asserts! (is-project-client project-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status milestone) "submitted") ERR-INVALID-STATUS)
    (asserts! (>= (get funds-deposited project) payment-amount) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer payment to freelancer
    (try! (as-contract (stx-transfer? net-payment tx-sender freelancer)))
    
    ;; Transfer platform fee
    (try! (as-contract (stx-transfer? platform-fee tx-sender (var-get platform-treasury))))
    
    ;; Update milestone status
    (map-set milestones
      { project-id: project-id, milestone-id: milestone-id }
      (merge milestone
        {
          status: "paid",
          approved-at: (some burn-block-height),
          paid-at: (some burn-block-height)
        }
      )
    )
    
    ;; Update project stats
    (let ((updated-completed (+ (get completed-milestones project) u1)))
      (map-set projects project-id
        (merge project
          {
            completed-milestones: updated-completed,
            funds-deposited: (- (get funds-deposited project) payment-amount),
            status: (if (is-eq updated-completed (get total-milestones project)) "completed" "active")
          }
        )
      )
      
      ;; If project completed, update completion timestamp and user stats
      (if (is-eq updated-completed (get total-milestones project))
        (begin
          (map-set projects project-id
            (merge (unwrap-panic (map-get? projects project-id))
              { completed-at: (some burn-block-height) }
            )
          )
          (update-freelancer-stats freelancer net-payment)
          (update-client-stats tx-sender payment-amount)
        )
        true
      )
    )
    
    (ok net-payment)
  )
)

;; Rate project participant
(define-public (rate-participant (project-id uint) (rating uint) (feedback (string-ascii 200)))
  (let ((project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND)))
    (asserts! (is-project-participant project-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status project) "completed") ERR-PROJECT-COMPLETED)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-STATUS)
    
    (map-set project-ratings
      { project-id: project-id, rater: tx-sender }
      {
        rating: rating,
        feedback: feedback,
        rated-at: burn-block-height
      }
    )
    
    (ok rating)
  )
)

;; Read-only functions

(define-read-only (get-project (project-id uint))
  (map-get? projects project-id)
)

(define-read-only (get-milestone (project-id uint) (milestone-id uint))
  (map-get? milestones { project-id: project-id, milestone-id: milestone-id })
)

(define-read-only (get-freelancer-profile (freelancer principal))
  (map-get? freelancer-profiles freelancer)
)

(define-read-only (get-client-profile (client principal))
  (map-get? client-profiles client)
)

(define-read-only (get-project-application (project-id uint) (freelancer principal))
  (map-get? project-applications { project-id: project-id, freelancer: freelancer })
)

(define-read-only (get-project-rating (project-id uint) (rater principal))
  (map-get? project-ratings { project-id: project-id, rater: rater })
)

(define-read-only (get-platform-stats)
  {
    total-projects: (var-get total-projects-created),
    total-funds-escrowed: (var-get total-funds-escrowed),
    next-project-id: (var-get next-project-id),
    platform-treasury: (var-get platform-treasury)
  }
)
