# Architecture & Design Lens

Apply to diffs introducing new modules, modifying system boundaries, refactoring domain logic, altering public contracts, or changing dependency structure.

## Severity Guide

| Severity | Impact | Examples |
|---|---|---|
| **P0** (Blocker) | Architectural regression, severe coupling, circular build cycles | Circular dependency breaking runtime module resolution; Domain layer importing HTTP framework/presentation code; bypassing tenant isolation boundaries |
| **P1** (Likely bug) | Boundary leakage, unmaintainable coupling, broken testability | Business rules duplicated across controllers instead of domain/service layer; entity directly executing DB queries (leaking persistence into domain); global mutable state introduced |
| **P2** (Maintainability) | Violations of SOLID/DDD patterns, code smell | Fat controller doing orchestration, validation, and domain calculation; missing interface/abstraction for third-party SDK; inconsistent naming conventions |
| **P3** (Minor) | Minor modularity improvement, aesthetic refactoring | Moving utility function to more cohesive module; minor parameter object extraction |

---

## Layering & Dependency Direction

- **Clean Architecture & DDD Boundary Enforcement**:
  - `Domain` layer must be pure: no dependencies on `Infrastructure`, `HTTP`, ORM models, or frameworks.
  - `Application` layer orchestrates domain models and use cases: depends only on `Domain` and abstraction interfaces.
  - `Infrastructure` implements interfaces defined by Domain/Application (repositories, mailers, payment gateways).
  - Presentation / HTTP controllers must only validate requests, invoke application use cases, and format responses.
- **Dependency Inversion**:
  - High-level business logic must not depend directly on concrete low-level implementations (e.g. direct Stripe client, AWS S3 SDK). Prefer interfaces injected via constructor.
- **Circular Dependencies**:
  - Module A must not import Module B if Module B directly or indirectly imports Module A.

---

## Single Responsibility & Cohesion

- **Fat Controllers & Handlers**:
  - A controller should not exceed ~100–150 lines. If a controller method handles validation, permission checks, entity mutation, database queries, emails, and auditing, extract an Action, Command Handler, or Service class.
- **God Classes & Anemic Models**:
  - Avoid creating helper classes with dozens of unrelated static methods (`Utils`, `Helpers`).
  - Favor rich domain entities with meaningful behavior over anemic data bags manipulated by bloated procedural services.

---

## Extensibility & Public Contracts

- **Interface Segregation**:
  - Clients should not be forced to depend on methods they do not use. Keep interfaces focused and granular.
- **Contract Stability**:
  - Public exports and API contracts must remain stable. Breaking changes require versioning or deprecation warnings.
- **Encapsulation & Information Hiding**:
  - Keep internal implementation details private. Expose only what consumers strictly need.
  - Avoid exposing mutable collections or internal state directly.

