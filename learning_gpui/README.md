# Learning GPUI: From Zero to Contributor

A comprehensive tutorial series teaching both Rust and GPUI (Zed's UI framework) simultaneously. Designed for experienced programmers who want to learn Rust through practical UI development, with a focus on hands-on learning and real-world patterns.

## Who This Is For

- Experienced Python (or similar language) programmers
- People who want to learn Rust by building something tangible
- Developers interested in contributing to Zed
- Anyone curious about building native desktop UIs with Rust

## What You'll Learn

- Rust fundamentals: ownership, borrowing, traits, lifetimes, async/await
- GPUI architecture: entities, contexts, elements, rendering pipeline
- Building interactive UIs with events, actions, and keyboard navigation
- Reactive patterns: subscriptions, observers, and data flow
- Advanced patterns: custom elements, testing, performance optimization
- Contributing to the Zed codebase

## How to Use This Tutorial

Each part builds on the previous ones. Start with Part 1 and work through sequentially. The tutorial emphasizes:

- **Hands-on learning**: You'll write code from the start
- **Top-down approach**: Start with working examples, then understand how they work
- **Practical focus**: Real patterns used in production code, not toy examples
- **Python comparisons**: See how Rust concepts map to Python equivalents

## The Series

### Part 1: Your First GPUI Application
[`part_01_your_first_gpui_app.md`](./part_01_your_first_gpui_app.md)

Get a window on screen in five minutes. Learn Rust basics (structs, traits, functions) by building a simple app. Understand the render trait and element trees.

**Key concepts**: Structs, traits, closures, ownership basics

### Part 2: Ownership and Making Things Happen
[`part_02_ownership_and_making_things_happen.md`](./part_02_ownership_and_making_things_happen.md)

Add interactivity to your app. Understand Rust's ownership system deeply through practical examples. Learn how `cx.listener` and `cx.notify()` work.

**Key concepts**: Ownership, borrowing, move semantics, event handlers

### Part 3: Element Trees and Composition
[`part_03_element_trees_and_composition.md`](./part_03_element_trees_and_composition.md)

Build a todo list with dynamic content. Learn element composition, conditional rendering, and iterating over collections. Understand GPUI's rendering pipeline.

**Key concepts**: Element composition, `.children()`, `.when()`, rendering pipeline

### Part 4: Events, Actions, and Keyboard-Driven UI
[`part_04_events_actions_and_keyboard_driven_ui.md`](./part_04_events_actions_and_keyboard_driven_ui.md)

Add keyboard navigation and actions. Understand input events, the action system, focus management, and event bubbling.

**Key concepts**: Input events, actions, focus, keyboard handling

### Part 5: Entities, The Beating Heart of GPUI
[`part_05_entities_the_beating_heart_of_gpui.md`](./part_05_entities_the_beating_heart_of_gpui.md)

Understand how entities solve the ownership problem in UI frameworks. Learn about weak references, entity lifecycle, and building apps with multiple communicating components.

**Key concepts**: `Entity<T>`, `WeakEntity<T>`, entity lifecycle, avoiding cycles

### Part 6: Async Without Tears
[`part_06_async_without_tears.md`](./part_06_async_without_tears.md)

Keep your UI responsive with async operations. Learn `cx.spawn()` and `cx.background_spawn()`, error handling, debouncing, and parallel tasks.

**Key concepts**: `cx.spawn()`, `cx.background_spawn()`, `Task<T>`, async patterns

### Part 7: Styling, Layout, and Making Things Look Less Terrible
[`part_07_styling_layout_and_making_things_look_less_terrible.md`](./part_07_styling_layout_and_making_things_look_less_terrible.md)

Master GPUI's styling system (inspired by Tailwind CSS). Learn flexbox, sizing, colors, borders, shadows, hover states, and building complex layouts.

**Key concepts**: Flexbox, styling methods, layout patterns, performance

### Part 8: Subscriptions, Observers, and Reactive Patterns
[`part_08_subscriptions_observers_and_reactive_patterns.md`](./part_08_subscriptions_observers_and_reactive_patterns.md)

Make components react to each other. Learn entity events, subscriptions, observers, and reactive data flow. Build UIs where changes propagate automatically.

**Key concepts**: `cx.subscribe()`, `cx.observe()`, events, reactive patterns

### Part 9: Building Real Components
[`part_09_building_real_components.md`](./part_09_building_real_components.md)

Put it all together by building a real, reusable component: a searchable, filterable list with keyboard navigation. Learn testing, generics, and packaging for reuse.

**Key concepts**: Generics, trait objects, testing with `TestApp`, component design

### Part 10: Contributing to Zed and Advanced Patterns
[`part_10_contributing_to_zed_and_advanced_patterns.md`](./part_10_contributing_to_zed_and_advanced_patterns.md)

Navigate the Zed codebase. Understand advanced patterns: custom elements, the project system, settings, and production-level code. Learn how to submit your first PR.

**Key concepts**: Zed architecture, custom `Element` trait, contributing workflow

## Quick Start

1. Make sure you have Rust installed:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

2. Clone the Zed repository (if you haven't):
```bash
git clone https://github.com/zed-industries/zed.git
cd zed
```

3. Start with Part 1:
```bash
cat learning_gpui/part_01_your_first_gpui_app.md
```

4. Build and run examples as you go:
```bash
cargo run --example hello_world
```

## Prerequisites

- Comfortable with at least one programming language (Python, JavaScript, etc.)
- Basic understanding of UI concepts (views, events, rendering)
- Willingness to learn a systems programming language
- A computer with Rust installed

No prior Rust knowledge required. No prior UI framework experience required.

## Additional Resources

- [GPUI Examples](../crates/gpui/examples/): Working examples in the GPUI crate
- [Zed Documentation](https://zed.dev/docs): Official Zed documentation
- [The Rust Book](https://doc.rust-lang.org/book/): Comprehensive Rust tutorial
- [Rust by Example](https://doc.rust-lang.org/rust-by-example/): Learn Rust with runnable examples

## Contributing to This Tutorial

Found a mistake? Have a suggestion? This tutorial lives in the Zed repository. Feel free to submit improvements.

## Philosophy

This tutorial was designed with several principles:

1. **Learn by doing**: Write code from the start, understand it later
2. **Real patterns**: Use patterns from production code, not simplified versions
3. **Honest complexity**: Don't hide the hard parts; explain them clearly
4. **Practical focus**: Build things you'd actually use, not contrived examples
5. **Comparisons help**: Relate new concepts to familiar ones (Python, React, etc.)
6. **Respect your intelligence**: No hand-holding, no patronizing language

## Progression Overview

```
Part 1-2: Rust basics + Simple UI
    ↓
Part 3-4: Dynamic content + Interaction
    ↓
Part 5-6: Architecture + Async
    ↓
Part 7-8: Styling + Reactivity
    ↓
Part 9: Real component
    ↓
Part 10: Production codebase
```

By the end, you'll understand:
- How to read and write Rust code
- How GPUI works under the hood
- How to build complex, performant UIs
- How to contribute to Zed

## Time Commitment

- **Fast track**: 8-12 hours (skim, run examples, basic understanding)
- **Thorough**: 20-30 hours (read carefully, build projects, deep understanding)
- **Mastery**: 40+ hours (complete all exercises, build your own components, contribute to Zed)

## Next Steps After Completion

1. Build a GPUI project from scratch
2. Find a "good first issue" in Zed and fix it
3. Read GPUI's source code to understand implementation details
4. Join the Zed community (Discord, GitHub discussions)
5. Share what you've built

## License

This tutorial is part of the Zed project and follows the same license.

## Acknowledgments

Built on the shoulders of:
- The Zed team for creating GPUI
- The Rust community for excellent tooling and documentation
- Fast.ai for pioneering top-down, practical teaching methods

---

Start with [Part 1: Your First GPUI Application](./part_01_your_first_gpui_app.md) and begin your journey from zero to contributor.
