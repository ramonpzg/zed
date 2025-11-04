# Part 2: Ownership and Making Things Happen

The counter from Part 1 doesn't count. Let's fix that, and in doing so, understand why Rust and GPUI work the way they do.

## What We're Building

A counter that increments when you click it. Simple in Python:

```python
class Counter:
    def __init__(self):
        self.count = 0

    def on_click(self):
        self.count += 1
```

In Rust with GPUI, it looks like this:

```rust
use gpui::*;

struct Counter {
    count: usize,
}

impl Render for Counter {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .flex()
            .bg(rgb(0x1e1e1e))
            .size_full()
            .items_center()
            .justify_center()
            .text_xl()
            .text_color(rgb(0xffffff))
            .child(format!("Count: {}", self.count))
            .on_click(cx.listener(|this, _event, _window, _cx| {
                this.count += 1;
            }))
    }
}

fn main() {
    App::new().run(|cx: &mut App| {
        cx.open_window(WindowOptions::default(), |window, cx| {
            cx.new(|_cx| Counter { count: 0 })
        })
        .unwrap();
    });
}
```

The new part is:

```rust
.on_click(cx.listener(|this, _event, _window, _cx| {
    this.count += 1;
}))
```

Before we explain what `cx.listener` does, we need to understand Rust's ownership system. Otherwise, this line will look like magic, and not the good kind.

## The Three Rules of Ownership

Rust's memory model has three rules. These are not guidelines; they're enforced by the compiler.

**Rule 1: Each value has a single owner.**

```rust
let s = String::from("hello");
```

Here, `s` owns the string `"hello"`. When `s` goes out of scope, the string is dropped (freed from memory).

In Python, you'd write:

```python
s = "hello"
```

When `s` goes out of scope, Python's garbage collector eventually frees it. Rust doesn't have a garbage collector. Instead, it frees memory as soon as the owner goes out of scope. This is deterministic: you know exactly when memory is freed.

**Rule 2: When the owner goes out of scope, the value is dropped.**

```rust
{
    let s = String::from("hello");
    // s is valid here
}
// s is no longer valid here; memory has been freed
```

Python equivalent:

```python
def some_function():
    s = "hello"
    # s is valid here
# s is no longer in scope, but the string might still exist if something else references it
```

Python's garbage collector decides when to free memory. Rust frees it immediately after the closing `}`.

**Rule 3: Only one mutable reference OR multiple immutable references at a time.**

This is the rule that makes Rust different. You can have:

- One `&mut T` (mutable borrow)
- OR many `&T` (immutable borrows)
- BUT NOT BOTH

```rust
let mut s = String::from("hello");

let r1 = &s;     // Immutable borrow
let r2 = &s;     // Another immutable borrow (OK)
println!("{}, {}", r1, r2);

let r3 = &mut s; // Mutable borrow (ERROR: can't borrow mutably while immutably borrowed)
```

The compiler will reject this. If you want a mutable reference, you can't have any immutable references active.

Why? Because mutable references can change the data, which would invalidate the immutable references. Rust prevents this at compile time, eliminating an entire class of bugs.

Python doesn't have this concept. You can have as many references to an object as you want, and any of them can modify it. This is flexible but dangerous in multithreaded code.

```python
s = ["hello"]
r1 = s  # Reference
r2 = s  # Another reference
r1.append("world")  # Modifying through r1
print(r2)  # r2 sees the change
```

In single-threaded Python, this is fine. In multithreaded Python, this causes data races unless you use locks. Rust eliminates the need for locks (in most cases) by enforcing exclusive access at compile time.

## Why This Matters for GPUI

GPUI is single-threaded. All UI updates happen on one thread. So why does ownership matter?

Because GPUI needs to ensure that when you're updating a piece of UI state, nothing else can access it simultaneously. If you're in the middle of rendering a view, GPUI can't let you start another render of the same view from an event handler. That would corrupt the state.

Rust's ownership system guarantees this. When you have `&mut Context<Self>` in a `render` method, the compiler proves that no other code can access that context simultaneously.

Let's see this in action.

## The Problem: Closures and Ownership

Look at the click handler again:

```rust
.on_click(cx.listener(|this, _event, _window, _cx| {
    this.count += 1;
}))
```

What is `this`? It's a reference to `Counter`. But how does the closure get access to `Counter`?

If you tried to write this in Python:

```python
def render(self):
    return (
        Div()
        .on_click(lambda: self.count += 1)  # ERROR: lambda can't contain assignments
    )
```

You'd need to restructure it:

```python
def render(self):
    def on_click():
        self.count += 1

    return Div().on_click(on_click)
```

The nested function captures `self` by reference. Python's runtime handles this.

Rust can't rely on a runtime. It needs to know at compile time:

1. Does the closure own the values it captures, or borrow them?
2. If it borrows, for how long?
3. Can the closure outlive the values it references?

For our click handler, the closure needs to:

1. Borrow `Counter` mutably (to increment `count`)
2. Live as long as the UI element exists
3. Be called multiple times (so it can't *consume* `Counter`)

This is tricky. The closure needs access to `Counter`, but `Counter` is owned by GPUI, not by us. We can't move `Counter` into the closure, because then GPUI wouldn't have it anymore.

Enter `cx.listener`.

## `cx.listener`: The Magic Spell

```rust
cx.listener(|this, _event, _window, _cx| {
    this.count += 1;
})
```

`cx.listener` is a method on `Context<Self>` (where `Self` is `Counter`). It takes a closure and returns a callback that GPUI can invoke later.

The closure's signature is:

```rust
|this: &mut Counter, event: &ClickEvent, window: &mut Window, cx: &mut Context<Counter>| { ... }
```

(I've added type annotations for clarity; they're usually inferred.)

Notice that the closure takes `this: &mut Counter` as its first argument. This is not `self`. It's a reference to the `Counter` that GPUI is managing.

When you call `cx.listener`, GPUI stores a reference to the `Counter` entity and associates the closure with it. Later, when the click event happens, GPUI:

1. Retrieves the `Counter` entity
2. Locks it (ensuring no other code can access it)
3. Calls your closure with `&mut Counter`
4. Unlocks it

This is how GPUI gives you mutable access to your view's state from an event handler without violating Rust's ownership rules.

In Python terms:

```python
class Context:
    def listener(self, closure):
        def wrapper(event, window, cx):
            # Lock the entity (hypothetically)
            entity = self.get_entity()
            closure(entity, event, window, cx)
            # Unlock the entity
        return wrapper
```

But Rust's version is checked at compile time, so you can't accidentally access the entity from two places at once.

## Notifying the UI

There's a subtlety here. If you run the code above, the counter increments, but the UI doesn't update.

Why? Because GPUI doesn't know the state changed. Rendering happens at 60 FPS, but only for views that have been marked as "dirty" (needing a re-render).

To fix this, call `cx.notify()`:

```rust
.on_click(cx.listener(|this, _event, _window, cx| {
    this.count += 1;
    cx.notify();
}))
```

`cx.notify()` tells GPUI "this entity's state changed; re-render it on the next frame."

In Python GUI frameworks, this often happens automatically:

```python
def on_click(self):
    self.count += 1  # Framework notices and schedules a re-render
```

GPUI makes it explicit. This gives you control over when re-renders happen, which matters for performance when you have complex UIs.

## The Complete Code

```rust
use gpui::*;

struct Counter {
    count: usize,
}

impl Render for Counter {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .flex()
            .bg(rgb(0x1e1e1e))
            .size_full()
            .items_center()
            .justify_center()
            .text_xl()
            .text_color(rgb(0xffffff))
            .child(format!("Count: {}", self.count))
            .on_click(cx.listener(|this, _event, _window, cx| {
                this.count += 1;
                cx.notify();
            }))
    }
}

fn main() {
    App::new().run(|cx: &mut App| {
        cx.open_window(WindowOptions::default(), |window, cx| {
            cx.new(|_cx| Counter { count: 0 })
        })
        .unwrap();
    });
}
```

Run it. Click the window. Watch the counter increment. You're now officially modifying state in a Rust GUI framework.

## Borrowing in Practice

Let's look at a common mistake. Suppose you want to use `self.count` in the closure:

```rust
.on_click(cx.listener(|this, _event, _window, cx| {
    let current = self.count;  // ERROR: can't capture `self`
    this.count = current + 1;
    cx.notify();
}))
```

This won't compile. The closure can't capture `self` because `self` (the `Counter` instance in `render`) is already borrowed by the `render` method. If the closure captured it, you'd have two references to the same data: one in `render` and one in the closure.

Rust forbids this. The solution is to use `this` instead:

```rust
.on_click(cx.listener(|this, _event, _window, cx| {
    let current = this.count;
    this.count = current + 1;
    cx.notify();
}))
```

This works because `this` is provided by GPUI when the closure is invoked, not when it's created. At invocation time, GPUI ensures no other code has access to `Counter`.

## Move Semantics

Let's say you want to increment by a variable amount:

```rust
let amount = 5;
.on_click(cx.listener(|this, _event, _window, cx| {
    this.count += amount;  // ERROR: `amount` not captured
    cx.notify();
}))
```

This won't compile because `amount` is not in scope when the closure is invoked. The closure needs to *capture* `amount`.

Rust closures can capture in three ways:

1. **By reference** (`&T`): Borrow the value
2. **By mutable reference** (`&mut T`): Borrow mutably
3. **By value** (move): Take ownership

For primitive types like `usize`, capturing by value is cheap (it's just copying an integer):

```rust
let amount = 5;
.on_click(cx.listener(move |this, _event, _window, cx| {
    this.count += amount;
    cx.notify();
}))
```

The `move` keyword tells Rust to move `amount` into the closure. Since `usize` implements `Copy`, this actually copies it.

For non-`Copy` types (like `String`), `move` transfers ownership:

```rust
let message = String::from("clicked");
.on_click(cx.listener(move |this, _event, _window, cx| {
    println!("{}", message);  // `message` is owned by the closure
    cx.notify();
}))
// `message` is no longer accessible here
```

If you try to use `message` after the closure, the compiler will complain. The closure now owns it.

If you need to use `message` in multiple closures, you have two options:

1. **Clone it**:

```rust
let message = String::from("clicked");
let message_clone = message.clone();
.on_click(cx.listener(move |this, _event, _window, cx| {
    println!("{}", message_clone);
    cx.notify();
}))
// `message` is still usable here
```

2. **Use `Arc` (atomic reference counting)**:

```rust
use std::sync::Arc;

let message = Arc::new(String::from("clicked"));
let message_clone = message.clone();  // Clones the Arc, not the String
.on_click(cx.listener(move |this, _event, _window, cx| {
    println!("{}", message_clone);
    cx.notify();
}))
// Both `message` and `message_clone` point to the same String
```

`Arc` is like Python's reference counting, but explicit. It allows multiple owners of the same data. When the last `Arc` is dropped, the data is freed.

## The Entity System Preview

We've been treating `Counter` as if it's just a struct, but when you call `cx.new(|_cx| Counter { count: 0 })`, GPUI wraps it in an `Entity<Counter>`.

An entity is a handle to state managed by GPUI. It solves the closure problem in a different way than `cx.listener`. We'll explore entities in depth in Part 5, but here's a preview:

```rust
let counter: Entity<Counter> = cx.new(|_cx| Counter { count: 0 });

// Later, elsewhere:
counter.update(cx, |counter, cx| {
    counter.count += 1;
    cx.notify();
});
```

`Entity<Counter>` can be cloned cheaply (it's just a reference-counted pointer). You can pass it to closures, store it in other structs, and access it from anywhere in your app, as long as you have access to `cx`.

This is how GPUI lets you build complex UIs with multiple components that need to communicate. We'll see this in action starting in Part 5.

## Summary: Ownership and Borrowing

1. **Each value has one owner.** When the owner goes out of scope, the value is dropped.
2. **Borrowing**: `&T` is an immutable reference; `&mut T` is a mutable reference.
3. **At any time**, you can have either one `&mut T` OR many `&T`, but not both.
4. **`cx.listener`** creates closures that borrow your view mutably when invoked.
5. **`cx.notify()`** marks the view as needing a re-render.
6. **`move` closures** capture variables by value (taking ownership).
7. **`Arc`** allows shared ownership when you need multiple references.

## What's Next

In Part 3, we'll build more complex element trees: nested layouts, conditional rendering, and lists. You'll learn how GPUI's element system compares to React's virtual DOM, and why it's faster.

By now, you've written Rust code that compiles, runs, and responds to user input. The hard part is over. The rest is learning patterns.
