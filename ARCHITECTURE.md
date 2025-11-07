
# Contents:

1. project Structure
2. Architecture


# Project Structure
lib/
├── main.dart                          # App entry point
├── core/
│   ├── data/
│   │   ├── database.dart              # Drift database definition
│   │   └── database.g.dart            # Generated database code
│   ├── models/                        # Data models (Participant, Account, etc.)
│   ├── services/                      # Business logic services
│   │   ├── service_locator.dart       # Dependency injection
│   │   ├── participant_service.dart
│   │   ├── budget_service.dart
│   │   ├── transaction_service.dart
│   │   ├── template_service.dart
│   │   ├── sync_service.dart
│   │   ├── analytics_service.dart
│   │   ├── remote_service.dart
│   │   ├── google_sheets_service.dart
│   │   └── parsers/                   # PDF parsing system
│   │       ├── pdf_parser_interface.dart
│   │       ├── parser_factory.dart
│   │       ├── hsbc_parser.dart
│   │       ├── mpesa_parser.dart
│   │       ├── equity_parser.dart
│   │       ├── coop_parser.dart
│   │       ├── generic_parser.dart
│   │       └── budget_spreadsheet_mapper.dart
│   └── routing/
│       └── app_router.dart            # Navigation setup
└── features/                          # Feature-based organization
├── onboarding/
│   ├── views/
│   │   └── onboarding_page.dart
│   └── viewmodels/
│       └── onboarding_viewmodel.dart
├── home/
│   ├── views/
│   │   └── home_page.dart
│   └── viewmodels/
│       └── home_viewmodel.dart
├── budgeting/
│   ├── views/
│   │   └── budgeting_page.dart
│   └── viewmodels/
│       └── budgeting_viewmodel.dart
└── audit/
├── views/
│   └── audit_page.dart
└── viewmodels/
└── audit_viewmodel.dart


# Architecture
