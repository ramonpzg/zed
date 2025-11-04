# Part 5: Entities, The Beating Heart of GPUI

You've been using `Entity<T>` since Part 1, but we've hand-waved what it actually does. Let's fix that. Understanding entities is the key to building complex GPUI applications that don't collapse into a mess of lifetimes and borrow checker errors.

## The Problem Entities Solve

Imagine you're building a text editor. You have:

- A `Workspace` that manages windows and panes
- A `Buffer` that holds the text content
- An `Editor` view that displays the buffer
- A `ProjectPanel` that shows the file tree
- A `Terminal` that runs shell commands

These components need to reference each other:

- The `Editor` needs a reference to the `Buffer` to display it
- The `Workspace` needs references to all open editors and panels
- The `ProjectPanel` needs to know about the current workspace to open files

In Python, you'd just store references:

```python
class Editor:
    def __init__(self, buffer):
        self.buffer = buffer  # Reference to buffer

class Workspace:
    def __init__(self):
        self.editors = []  # List of editors
        self.buffer = Buffer()
        self.editors.append(Editor(self.buffer))
```

Python's garbage collector handles the memory management. When nothing references a `Buffer` anymore, it gets cleaned up eventually.

In Rust, you can't do this. If `Editor` owns `buffer`, then `Workspace` can't also own it (rule 1: each value has one owner). If `Editor` borrows `buffer` with `&Buffer`, then you need to specify the lifetime:

```rust
struct Editor<'a> {
    buffer: &'a Buffer,
}
```

Now `Editor` can't outlive `Buffer`. But what if you want to close the editor but keep the buffer open? Or close the buffer but keep the editor around (to show an error message)? Lifetimes get messy fast.

The traditional Rust solution: `Rc<RefCell<Buffer>>` (reference-counted smart pointer with interior mutability). But that's verbose and easy to misuse (you can create circular references that leak memory).

GPUI's solution: entities.

## What Is an Entity?

An `Entity<T>` is a handle to state of type `T` managed by GPUI. It's like `Rc<RefCell<T>>`, but integrated into GPUI's lifecycle:

1. **Reference-counted**: You can clone `Entity<T>` cheaply
2. **Runtime-checked borrowing**: Rust's borrow checker is bypassed in favor of runtime checks
3. **Lifetime management**: GPUI drops entities when they're no longer used
4. **Context-bound**: You can only access entities through a context (`cx`)

Creating an entity:

```rust
let buffer: Entity<Buffer> = cx.new(|cx| Buffer::new());
```

`cx.new()` takes a closure that returns the value. GPUI wraps it in an entity and gives you a handle.

Cloning the handle:

```rust
let buffer2 = buffer.clone();  // Cheap: just increments a reference count
```

Both `buffer` and `buffer2` point to the same `Buffer` instance.

## Reading and Updating Entities

You can't access the entity's data directly. You must go through the context:

```rust
// Read (immutable access)
let text = buffer.read(cx).text.clone();

// Update (mutable access)
buffer.update(cx, |buffer, cx| {
    buffer.text = "new text".to_string();
    cx.notify();  // Mark for re-render if it's a view
});
```

### Why the closure?

Because GPUI enforces exclusivity at runtime. When you call `.update()`, GPUI:

1. Checks if the entity is already borrowed
2. If not, locks it (mutable borrow)
3. Calls your closure with `&mut T`
4. Unlocks it

If you try to update an entity while it's already borrowed, GPUI panics. This is the runtime version of Rust's compile-time borrow checking.

In Python terms:

```python
# Python (no locking needed in single-threaded code)
buffer.text = "new text"
```

```rust
// Rust with Entity
buffer.update(cx, |buffer, cx| {
    buffer.text = "new text".to_string();
});
```

The closure ensures the borrow is scoped. After the closure returns, the entity is unlocked.

## Weak References

If you store `Entity<T>` in another entity, you create a strong reference. If two entities reference each other, you have a reference cycle, and they'll never be dropped (memory leak).

Solution: `WeakEntity<T>`.

```rust
struct Editor {
    buffer: Entity<Buffer>,  // Strong reference
}

struct Buffer {
    editors: Vec<WeakEntity<Editor>>,  // Weak references to avoid cycles
}
```

When an `Editor` is dropped, the `WeakEntity<Editor>` in `Buffer.editors` becomes invalid. You can check:

```rust
buffer.update(cx, |buffer, cx| {
    buffer.editors.retain(|editor| editor.upgrade().is_some());
});
```

`upgrade()` returns `Option<Entity<Editor>>`. If the entity was dropped, you get `None`.

## Entities in Action: A Two-Pane Editor

Let's build a simple two-pane editor. Each pane shows a different part of the same buffer.

```rust
use gpui::*;

struct Buffer {
    text: String,
}

struct EditorPane {
    buffer: Entity<Buffer>,
    scroll_offset: usize,
}

impl Render for EditorPane {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let text = self.buffer.read(cx).text.clone();

        div()
            .flex()
            .flex_col()
            .size_full()
            .bg(rgb(0x1e1e1e))
            .p_4()
            .child(
                div()
                    .text_color(rgb(0xffffff))
                    .child(format!("Buffer content: {}", text))
            )
            .child(
                div()
                    .mt_4()
                    .child("(This is a simplified editor pane)")
            )
    }
}

struct Workspace {
    buffer: Entity<Buffer>,
    left_pane: Entity<EditorPane>,
    right_pane: Entity<EditorPane>,
}

impl Render for Workspace {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .flex()
            .size_full()
            .child(
                div()
                    .flex_1()
                    .child(self.left_pane.clone())
            )
            .child(
                div()
                    .flex_1()
                    .child(self.right_pane.clone())
            )
    }
}

fn main() {
    App::new().run(|cx: &mut App| {
        cx.open_window(WindowOptions::default(), |window, cx| {
            cx.new(|cx| {
                let buffer = cx.new(|_cx| Buffer {
                    text: "Hello, world!".to_string(),
                });

                let left_pane = cx.new(|_cx| EditorPane {
                    buffer: buffer.clone(),
                    scroll_offset: 0,
                });

                let right_pane = cx.new(|_cx| EditorPane {
                    buffer: buffer.clone(),
                    scroll_offset: 0,
                });

                Workspace {
                    buffer,
                    left_pane,
                    right_pane,
                }
            })
        })
        .unwrap();
    });
}
```

Key points:

1. **`Workspace` owns `buffer`, `left_pane`, and `right_pane`**: These are strong references
2. **Both panes share the `buffer`**: They clone the `Entity<Buffer>` handle
3. **Rendering a view**: `.child(self.left_pane.clone())` renders the entity

When you pass an `Entity<T>` to `.child()`, GPUI calls its `render` method and inserts the resulting elements into the tree.

## Updating Shared State

Let's add a button to modify the buffer from one pane:

```rust
impl Render for EditorPane {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let text = self.buffer.read(cx).text.clone();

        div()
            .flex()
            .flex_col()
            .size_full()
            .bg(rgb(0x1e1e1e))
            .p_4()
            .child(
                div()
                    .text_color(rgb(0xffffff))
                    .child(format!("Buffer content: {}", text))
            )
            .child(
                div()
                    .mt_4()
                    .bg(rgb(0x0066cc))
                    .text_color(rgb(0xffffff))
                    .p_2()
                    .rounded_md()
                    .cursor_pointer()
                    .child("Append text")
                    .on_click(cx.listener(|this, _event, _window, cx| {
                        this.buffer.update(cx, |buffer, _cx| {
                            buffer.text.push_str(" More text!");
                        });
                        cx.notify();  // Notify the pane to re-render
                    }))
            )
    }
}
```

Click the button in either pane. The buffer updates, and both panes re-render (assuming you also call `cx.notify()` on the buffer or use observers, which we'll cover in Part 8).

Wait, that's not quite right. The pane re-renders (because `cx.notify()` is called on it), but the other pane doesn't. To fix that, we need to make the buffer observable. Let's defer that to Part 8. For now, understand that entities allow shared mutable state.

## The Context Hierarchy

Different context types provide different capabilities:

```rust
// App: Top-level context
cx.new(|cx| Buffer::new())             // Create entities
cx.bind_keys([...])                     // Register key bindings

// Context<T>: Entity-specific context
cx.new(|cx| ...)                        // Can still create entities (derefs to App)
cx.notify()                             // Mark this entity for re-render
cx.emit(event)                          // Emit an event from this entity
cx.listener(|this, ...| ...)            // Create a listener with access to `this`

// Window: Window-specific operations
window.focus(handle)                    // Set focus
window.dispatch_action(action, cx)      // Dispatch an action
```

`Context<T>` derefs to `App`, so you can call `App` methods on it. This is why `cx.new()` works inside entity methods.

## Common Patterns

### Pattern 1: Store Entity Handles

```rust
struct Parent {
    children: Vec<Entity<Child>>,
}
```

Clone the handles freely. They're cheap.

### Pattern 2: Notify After Mutation

```rust
entity.update(cx, |entity, cx| {
    entity.field = new_value;
    cx.notify();  // Don't forget this!
});
```

If you forget `cx.notify()`, the view won't re-render. This is a common bug.

### Pattern 3: Avoid Update-During-Update

```rust
// BAD: Updating entity B while updating entity A
entity_a.update(cx, |a, cx| {
    entity_b.update(cx, |b, cx| {  // This is OK if entity_b != entity_a
        // ...
    });
});

// PANIC: Updating entity A while already updating it
entity_a.update(cx, |a, cx| {
    entity_a.update(cx, |a, cx| {  // PANIC: already borrowed mutably
        // ...
    });
});
```

The first case is fine (updating different entities). The second panics (updating the same entity recursively).

If you need to defer updates, use `cx.spawn()` (covered in Part 6).

### Pattern 4: Entity Lifetimes in Closures

When capturing entities in closures, prefer weak references to avoid leaks:

```rust
let weak_buffer = buffer.downgrade();

cx.spawn(async move |cx| {
    // Later, in async code
    if let Some(buffer) = weak_buffer.upgrade() {
        buffer.update(&mut cx, |buffer, cx| {
            buffer.text = "updated".to_string();
        });
    }
})
```

If the buffer is dropped before the async task runs, `upgrade()` returns `None`, and the task gracefully does nothing.

## Entities vs. Python's Object Model

In Python, everything is a reference:

```python
buffer = Buffer()
editor1 = Editor(buffer)
editor2 = Editor(buffer)
# Both editors reference the same buffer
```

Rust with entities:

```rust
let buffer: Entity<Buffer> = cx.new(|_cx| Buffer::new());
let editor1 = cx.new(|_cx| Editor { buffer: buffer.clone() });
let editor2 = cx.new(|_cx| Editor { buffer: buffer.clone() });
```

The difference: Rust's version is checked. You can't access `buffer` without `cx`, and you can't mutate it while someone else is reading it. Python has no such checks, which is flexible but dangerous in concurrent scenarios.

## Entity Lifecycle

Entities are dropped when:

1. **All strong references (`Entity<T>`) are dropped**
2. **The entity's window is closed** (if it's a view)

When an entity is dropped, GPUI:

1. Calls its `Drop` implementation (if any)
2. Frees its memory
3. Invalidates all `WeakEntity<T>` references to it

You can observe this by implementing `Drop`:

```rust
impl Drop for Buffer {
    fn drop(&mut self) {
        println!("Buffer dropped!");
    }
}
```

Create a buffer, then drop all references:

```rust
{
    let buffer = cx.new(|_cx| Buffer { text: String::new() });
    // buffer is dropped here
}
// Prints: "Buffer dropped!"
```

## Entity IDs

Every entity has a unique ID:

```rust
let id: EntityId = entity.entity_id();
```

You can use this to compare entities for equality:

```rust
if entity_a.entity_id() == entity_b.entity_id() {
    // Same entity
}
```

This is cheaper than comparing the entities' data.

## Debugging: The Update-During-Update Panic

The most common panic you'll encounter:

```
thread 'main' panicked at 'Entity<Foo> is already borrowed mutably'
```

This means you tried to update an entity while it's already borrowed (usually in its own `render` or `update` method).

Common causes:

1. **Recursive update**: An entity updates itself during its own update
2. **Forgetting to use the inner `cx`**: In nested closures, use the closure's `cx`, not the outer one

Example of the second:

```rust
entity.update(cx, |entity, inner_cx| {
    // Use inner_cx here, not cx
    entity.field.update(inner_cx, |field, cx| {
        // ...
    });
});
```

If you accidentally use the outer `cx`, you'll get the panic.

## Summary

1. **`Entity<T>`** is a reference-counted handle to state managed by GPUI
2. **`cx.new()`** creates entities
3. **`.read(cx)` and `.update(cx, |entity, cx| ...)`** access entities
4. **`WeakEntity<T>`** prevents reference cycles
5. **Entities can be cloned cheaply** and shared across components
6. **`cx.notify()`** marks entities for re-render
7. **Update-during-update panics** are the most common mistake
8. **Entities are dropped** when all strong references are gone

## What's Next

In Part 6, we'll explore async programming in GPUI. You'll learn how to spawn background tasks, run expensive computations without blocking the UI, and bring results back to the foreground. This is essential for building responsive applications that don't freeze when loading files or running searches.

You now understand how GPUI manages state. The next challenge is managing *time*.
