# Freelancer Escrow Platform

A decentralized escrow service for freelance work built on the Stacks blockchain, featuring milestone-based payments and dispute resolution mechanisms.

## Overview

The Freelancer Escrow Platform provides a secure, transparent, and automated way to manage freelance projects and payments. It protects both clients and freelancers by holding funds in escrow until work milestones are completed and approved.

## Features

- **Milestone-Based Payments**: Break projects into manageable milestones with individual payment schedules
- **Secure Fund Escrow**: Client funds are securely held in smart contract until work approval
- **Dispute Resolution**: Built-in mediation system for handling project disagreements
- **Automated Releases**: Smart contract automatically releases payments upon milestone completion
- **Rating System**: Reputation tracking for both clients and freelancers
- **Multi-Project Support**: Handle multiple concurrent projects efficiently

## Smart Contracts

### work-escrow
The core contract that manages:
- Project creation and milestone definition
- Fund deposit and escrow management  
- Work submission and approval workflows
- Payment release automation
- Dispute handling and resolution
- Reputation and rating systems

## Architecture

The platform leverages:
- **Stacks Blockchain**: For decentralized execution and transparency
- **Clarity Smart Contracts**: For trustless automation and verifiable logic
- **STX Tokens**: Primary payment currency with support for other SIP-010 tokens
- **Time-Based Locks**: Automatic milestone deadlines and payment schedules

## Key Benefits

1. **Trust Minimization**: Smart contracts eliminate need for trusted intermediaries
2. **Payment Security**: Funds protected until work completion verification
3. **Global Accessibility**: Borderless freelance marketplace with crypto payments
4. **Transparent Workflows**: All project activities recorded on blockchain
5. **Lower Fees**: Reduced costs compared to traditional escrow services
6. **Dispute Protection**: Structured resolution process for project conflicts

## Use Cases

- Software development projects
- Design and creative work
- Content writing and marketing
- Consulting services
- Technical documentation
- Translation services
- Virtual assistance

## Security Features

- **Multi-Signature Controls**: Enhanced security for high-value projects
- **Milestone Validation**: Proof-of-work requirements before payment release
- **Deadline Enforcement**: Automatic actions based on project timelines
- **Dispute Mediation**: Neutral third-party resolution mechanisms
- **Reputation Verification**: Historical performance tracking
- **Fund Recovery**: Emergency procedures for stuck transactions

## Project Workflow

1. **Project Creation**: Client defines project scope and milestones
2. **Fund Deposit**: Client deposits total project payment into escrow
3. **Freelancer Selection**: Freelancers bid on project opportunities
4. **Work Execution**: Freelancer completes milestone deliverables
5. **Milestone Review**: Client reviews and approves completed work
6. **Payment Release**: Smart contract automatically releases milestone payment
7. **Project Completion**: Final deliverables submitted and payments released
8. **Rating Exchange**: Both parties provide feedback and ratings

## Payment Structure

- **Escrow Deposit**: Full project amount held securely
- **Milestone Releases**: Automatic payments upon approval
- **Platform Fees**: Minimal service fees for platform maintenance
- **Dispute Costs**: Mediation fees only when disputes occur
- **Emergency Refunds**: Client protection for abandoned projects

## Getting Started

1. Clone this repository
2. Install Clarinet development environment
3. Deploy contracts to testnet
4. Create client or freelancer profile
5. Post project or bid on available work
6. Execute project milestones
7. Complete payments and exchange ratings

## Development

This project uses Clarinet for smart contract development and testing.

```bash
# Install dependencies
npm install

# Check contract syntax
clarinet check

# Run test suite
clarinet test

# Deploy to testnet
clarinet deploy
```

## API Integration

The platform supports integration with:
- Project management tools
- Payment processors
- Communication platforms
- Time tracking systems
- Portfolio showcase sites

## License

MIT License - see LICENSE file for details.

## Contributing

Please read CONTRIBUTING.md for details on our code of conduct and the process for submitting pull requests.

## Support

For questions and support:
- Documentation: /docs
- Issues: GitHub Issues
- Community: Discord/Telegram channels