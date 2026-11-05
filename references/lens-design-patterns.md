# Lens: Design Patterns & Architectural Idioms

This reference provides a practical diagnostic guide for evaluating whether reviewed code or proposed architecture leverages existing project patterns, applies appropriate classic Design Patterns (Creational, Structural, Behavioral), or falls into the trap of procedural spaghetti or over-engineered "Patternitis".

---

## The Two Guiding Principles

1. **Leverage Before Inventing**: If the codebase already has an established pattern (e.g. `PaymentGatewayAdapter`, `NotificationStrategy`, `UserBuilder`), new code **must conform to that pattern** rather than introducing an ad-hoc alternative.
2. **Patterns are Solutions, Not Goals**: Never introduce a pattern unless it tangibly simplifies code, removes duplication, or isolates volatility. A pattern that adds 3 interfaces for a single static use case is YAGNI debt.

---

## 1. Creational Patterns (Object Creation Mechanisms)

Use when object creation logic is complex, conditional, or needs to decouple instantiation from usage.

| Pattern | Code Smell Detected in Review | When to Recommend | When it is Over-engineering |
|---|---|---|---|
| **Factory Method** | Direct `new Order(...)` scattered across 10 controllers with varying initialization logic | When subclassing or configuration determines which concrete class to instantiate | When there is only 1 concrete class that never changes |
| **Abstract Factory** | Hardcoded creation of families of related objects (e.g., UI widgets for Web vs Mobile, or SQL vs NoSQL drivers) | When creating entire suites of interdependent products without specifying concrete classes | When only a single product family exists |
| **Builder** | Constructors or methods with 6+ arguments, multiple optional parameters, or telescoping constructors | When assembling complex aggregate objects step-by-step with valid intermediate states | When the object has 2–3 simple fields (use simple object literal or constructor) |
| **Singleton** | Repeated instantiation of expensive, stateless connections (DB pools, logger, cache client) | When exactly one shared instance must coordinate actions across the system | Avoid using for domain logic or testable dependencies; prefer Dependency Injection singletons |
| **Prototype** | Costly initialization recalculated from scratch repeatedly | When cloning an existing pre-configured instance is cheaper than constructing from scratch | When creating new instances is cheap and trivial |

---

## 2. Structural Patterns (Assembling Objects & Classes)

Use to compose flexible, decoupled structures without creating rigid inheritance hierarchies.

| Pattern | Code Smell Detected in Review | When to Recommend | When it is Over-engineering |
|---|---|---|---|
| **Adapter** | Direct calls to 3rd-party vendor SDKs (Stripe, Twilio, SendGrid) inside core domain/business services | Wrap 3rd-party or legacy APIs behind an internal domain interface (Ports & Adapters) | Wrapping internal first-party services that you already control |
| **Facade** | Controller or client orchestrating 7 distinct low-level subsystem services in every request | Provide a simplified, high-level interface to a complex subsystem (e.g., `CheckoutFacade`) | When the subsystem only has 1 simple service call |
| **Decorator** | Bloating a class with `withLogging()`, `withCaching()`, `withMetrics()` branches | Add responsibilities dynamically without modifying underlying classes (e.g., CachingDecorator) | When standard middleware or aspect interceptors already exist in framework |
| **Composite** | Treating individual items and groups of items differently with duplicated recursive logic | When representing tree structures (menus, organization charts, filesystem nodes) uniformly | When the hierarchy is strictly flat or fixed |
| **Proxy** | Heavy object instantiated eagerly on startup even when rarely used, or missing lazy caching | Add lazy initialization, access control, or caching transparently before delegating | When direct access is lightweight and safe |
| **Bridge** | Cartesian explosion of classes (`RedCircle`, `BlueCircle`, `RedSquare`, `BlueSquare`) | Decouple an abstraction from its implementation so both can vary independently | Premature abstraction with only 1 dimension of variance |
| **Flyweight** | Millions of fine-grained immutable objects causing memory pressure | Share common intrinsic state among multiple objects (e.g., rich text formatting tokens) | When memory usage is negligible |

---

## 3. Behavioral Patterns (Algorithms & Responsibilities)

Use to untangle complex conditional logic, orchestrate event flows, or assign responsibilities cleanly.

| Pattern | Code Smell Detected in Review | When to Recommend | When it is Over-engineering |
|---|---|---|---|
| **Strategy** | Huge `switch (paymentMethod)` or nested `if/else` ladders (credit, pix, boleto, paypal) | When multiple algorithms or business rules can be swapped interchangeably at runtime | When there are only 2 fixed options that will never expand |
| **State** | Class riddled with flags: `if (isPending) ... else if (isApproved) ... else if (isShipped)` | When an object's behavior fundamentally changes based on its internal state machine | For binary flags (e.g. `isActive`) |
| **Command** | UI buttons or API actions directly coupled to execution logic, unable to queue, undo, or log | Encapsulate requests as standalone command objects (e.g., for CQRS, background queues, undo/redo) | For trivial synchronous CRUD operations |
| **Chain of Responsibility** | Sequential validation / sanitization logic baked into one 200-line monolithic method | Pass request through a pipeline of sequential handlers (e.g., authentication, throttling, schema check) | When the pipeline is fixed to 1 step |
| **Observer / Pub-Sub** | Component A calling B, C, D, E, F synchronously after mutation | Decouple subject from subscribers (e.g., `OrderPlaced` event notifies Email, Analytics, Inventory) | When only 1 subscriber exists and synchronous consistency is required |
| **Template Method** | 3 classes sharing 90% identical algorithm with only 1 step differing | Base class defines algorithm skeleton; subclasses override specific invariant steps | Prefer Composition over Inheritance (Strategy) when possible |
| **Mediator** | Many-to-many communication chaos between UI components or microservices | Centralize communication in a single coordinator to prevent circular dependencies | When components only talk to 1 neighbor |
| **Memento** | Exposing private state of objects to allow external undo/snapshots | Capture and restore object state without violating encapsulation | When state is publicly serializable or stateless |
| **Visitor** | Adding operations to a complex object structure without modifying its classes | Execute operations across heterogeneous composite structures | When the class hierarchy changes frequently |

---

## 4. Anti-Pattern Guard (Avoiding "Patternitis")

- **Rule of Two**: An abstraction or strategy is only warranted when **two active, distinct consumers exist today**.
- **Modern Simplicity**: In TypeScript, Python, or Go, passing a first-class function/callback often replaces an entire class hierarchy of Strategy or Command.
