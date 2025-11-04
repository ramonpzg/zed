# Part 9: Building Real Components

You've learned the pieces. Now let's build something real: a searchable, filterable list component. The kind of thing you'd actually use in an application, not a toy example with hardcoded data.

We'll build a component that:

- Displays a list of items
- Has a search input to filter items
- Supports keyboard navigation (arrow keys)
- Handles focus properly
- Performs well with thousands of items
- Is reusable and composable

This will tie together everything from Parts 1-8: entities, events, async, styling, and reactive patterns.

## The Component: SearchableList

```rust
use gpui::*;
use std::sync::Arc;

// Generic over the item type
pub struct SearchableList<T: Clone> {
    items: Arc<Vec<T>>,
    filtered_items: Vec<T>,
    search_query: String,
    selected_index: Option<usize>,
    focus_handle: FocusHandle,
    filter_fn: Arc<dyn Fn(&T, &str) -> bool + Send + Sync>,
    render_item_fn: Arc<dyn Fn(&T) -> String + Send + Sync>,
}

impl<T: Clone + Send + Sync + 'static> SearchableList<T> {
    pub fn new(
        items: Vec<T>,
        filter_fn: impl Fn(&T, &str) -> bool + Send + Sync + 'static,
        render_item_fn: impl Fn(&T) -> String + Send + Sync + 'static,
        cx: &mut Context<Self>,
    ) -> Self {
        let items = Arc::new(items);
        let filtered_items = items.to_vec();

        Self {
            items,
            filtered_items,
            search_query: String::new(),
            selected_index: Some(0),
            focus_handle: cx.focus_handle(),
            filter_fn: Arc::new(filter_fn),
            render_item_fn: Arc::new(render_item_fn),
        }
    }

    fn update_filter(&mut self, cx: &mut Context<Self>) {
        let query = self.search_query.to_lowercase();

        if query.is_empty() {
            self.filtered_items = self.items.to_vec();
        } else {
            let items = self.items.clone();
            let filter_fn = self.filter_fn.clone();

            cx.spawn(async move |this, cx| {
                let filtered = cx.background_spawn(async move {
                    items
                        .iter()
                        .filter(|item| filter_fn(item, &query))
                        .cloned()
                        .collect::<Vec<_>>()
                })
                .await;

                this.update(cx, |this, cx| {
                    this.filtered_items = filtered;
                    this.selected_index = if this.filtered_items.is_empty() {
                        None
                    } else {
                        Some(0)
                    };
                    cx.notify();
                })
                .ok();
            })
            .detach();
        }
    }

    fn move_selection(&mut self, delta: isize, cx: &mut Context<Self>) {
        if self.filtered_items.is_empty() {
            self.selected_index = None;
            return;
        }

        let new_index = if let Some(current) = self.selected_index {
            let new = current as isize + delta;
            if new < 0 {
                0
            } else if new >= self.filtered_items.len() as isize {
                self.filtered_items.len() - 1
            } else {
                new as usize
            }
        } else {
            0
        };

        self.selected_index = Some(new_index);
        cx.notify();
    }

    pub fn selected_item(&self) -> Option<&T> {
        self.selected_index
            .and_then(|idx| self.filtered_items.get(idx))
    }
}

impl<T: Clone + Send + Sync + 'static> Render for SearchableList<T> {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .track_focus(&self.focus_handle)
            .on_key_down(cx.listener(|this, event, _window, cx| {
                match event.keystroke.key.as_str() {
                    "down" => this.move_selection(1, cx),
                    "up" => this.move_selection(-1, cx),
                    _ => {}
                }
            }))
            .flex()
            .flex_col()
            .size_full()
            .bg(rgb(0x1e1e1e))
            .p_4()
            .gap_2()
            .child(
                // Search input (simplified; real version would be a proper text input)
                div()
                    .p_2()
                    .bg(rgb(0x2d2d2d))
                    .rounded_md()
                    .text_color(rgb(0xffffff))
                    .child(format!("Search: {}", self.search_query))
                    .child(
                        div()
                            .text_sm()
                            .text_color(rgb(0x888888))
                            .child("(Type to filter - simplified demo)")
                    )
            )
            .child(
                // Results list
                div()
                    .flex()
                    .flex_col()
                    .flex_1()
                    .overflow_y_scroll()
                    .gap_1()
                    .children(
                        self.filtered_items.iter().enumerate().map(|(idx, item)| {
                            let is_selected = self.selected_index == Some(idx);
                            let render_fn = self.render_item_fn.clone();
                            let text = render_fn(item);

                            div()
                                .p_2()
                                .rounded_md()
                                .bg(if is_selected {
                                    rgb(0x0066cc)
                                } else {
                                    rgb(0x2d2d2d)
                                })
                                .hover(|style| {
                                    style.bg(if is_selected {
                                        rgb(0x0052a3)
                                    } else {
                                        rgb(0x3d3d3d)
                                    })
                                })
                                .cursor_pointer()
                                .text_color(rgb(0xffffff))
                                .child(text)
                                .on_click(cx.listener(move |this, _event, _window, cx| {
                                    this.selected_index = Some(idx);
                                    cx.notify();
                                }))
                        })
                    )
            )
            .child(
                // Status bar
                div()
                    .text_sm()
                    .text_color(rgb(0x888888))
                    .child(format!(
                        "Showing {} of {} items",
                        self.filtered_items.len(),
                        self.items.len()
                    ))
            )
    }
}
```

## Breaking It Down

### Generics

```rust
pub struct SearchableList<T: Clone> {
    // ...
}
```

The component is generic over `T`, the item type. The `Clone` bound means items must be cloneable (so we can filter without borrowing issues).

In Python, you'd write:

```python
class SearchableList:
    def __init__(self, items: List[Any]):
        self.items = items
```

Rust's version is type-safe: if you create a `SearchableList<String>`, the compiler ensures you only use strings.

### Function Pointers

```rust
filter_fn: Arc<dyn Fn(&T, &str) -> bool + Send + Sync>,
render_item_fn: Arc<dyn Fn(&T) -> String + Send + Sync>,
```

These are trait objects (dynamic dispatch). `Arc<dyn Fn(...)>` is a reference-counted pointer to a function. This lets you pass custom filtering and rendering logic.

Why `Arc`? Because we need to clone these functions to move them into async closures. `Arc` allows shared ownership.

Why `Send + Sync`? Because we use them in background tasks. Rust requires that anything sent across threads implements `Send` and `Sync`.

In Python:

```python
class SearchableList:
    def __init__(self, items, filter_fn, render_fn):
        self.filter_fn = filter_fn
        self.render_fn = render_fn
```

Python doesn't care about thread safety. Rust does.

### Async Filtering

```rust
fn update_filter(&mut self, cx: &mut Context<Self>) {
    let query = self.search_query.to_lowercase();

    if query.is_empty() {
        self.filtered_items = self.items.to_vec();
    } else {
        let items = self.items.clone();
        let filter_fn = self.filter_fn.clone();

        cx.spawn(async move |this, cx| {
            let filtered = cx.background_spawn(async move {
                items
                    .iter()
                    .filter(|item| filter_fn(item, &query))
                    .cloned()
                    .collect::<Vec<_>>()
            })
            .await;

            this.update(cx, |this, cx| {
                this.filtered_items = filtered;
                this.selected_index = if this.filtered_items.is_empty() {
                    None
                } else {
                    Some(0)
                };
                cx.notify();
            })
            .ok();
        })
        .detach();
    }
}
```

We run the filter on a background thread (because with 10,000 items, it could take milliseconds). The UI stays responsive.

Clone the data (`items` and `filter_fn`) before spawning. Await the result. Update the entity on the foreground thread.

This pattern (from Part 6) is how you keep UIs snappy.

## Using the Component

```rust
use gpui::*;

#[derive(Clone)]
struct Person {
    name: String,
    email: String,
}

fn main() {
    App::new().run(|cx: &mut App| {
        cx.open_window(WindowOptions::default(), |window, cx| {
            let people = vec![
                Person {
                    name: "Alice".to_string(),
                    email: "alice@example.com".to_string(),
                },
                Person {
                    name: "Bob".to_string(),
                    email: "bob@example.com".to_string(),
                },
                Person {
                    name: "Charlie".to_string(),
                    email: "charlie@example.com".to_string(),
                },
                // ... add hundreds more
            ];

            let list = cx.new(|cx| {
                SearchableList::new(
                    people,
                    |person, query| {
                        person.name.to_lowercase().contains(query)
                            || person.email.to_lowercase().contains(query)
                    },
                    |person| format!("{} ({})", person.name, person.email),
                    cx,
                )
            });

            window.focus(&list.read(cx).focus_handle);

            list
        })
        .unwrap();
    });
}
```

The filter function checks if the query matches the name or email. The render function formats the display text.

Generics + closures = reusable component. You can use `SearchableList<Person>`, `SearchableList<File>`, `SearchableList<Project>`, etc., with different filtering and rendering logic.

## Testing: GPUI's Test Harness

GPUI provides a test context for unit testing UI components. Example:

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use gpui::*;

    #[gpui::test]
    fn test_searchable_list_filtering() {
        let mut cx = TestApp::new();

        let people = vec![
            Person {
                name: "Alice".to_string(),
                email: "alice@example.com".to_string(),
            },
            Person {
                name: "Bob".to_string(),
                email: "bob@example.com".to_string(),
            },
        ];

        let list = cx.new(|cx| {
            SearchableList::new(
                people,
                |person, query| person.name.to_lowercase().contains(query),
                |person| person.name.clone(),
                cx,
            )
        });

        // Initially, all items are shown
        list.read_with(&cx, |list, _cx| {
            assert_eq!(list.filtered_items.len(), 2);
        });

        // Update search query
        list.update(&mut cx, |list, cx| {
            list.search_query = "alice".to_string();
            list.update_filter(cx);
        });

        // Wait for async filter to complete
        cx.run_until_parked();

        // Only Alice should be shown
        list.read_with(&cx, |list, _cx| {
            assert_eq!(list.filtered_items.len(), 1);
            assert_eq!(list.filtered_items[0].name, "Alice");
        });
    }

    #[gpui::test]
    fn test_keyboard_navigation() {
        let mut cx = TestApp::new();

        let people = vec![
            Person { name: "Alice".to_string(), email: "".to_string() },
            Person { name: "Bob".to_string(), email: "".to_string() },
            Person { name: "Charlie".to_string(), email: "".to_string() },
        ];

        let list = cx.new(|cx| {
            SearchableList::new(
                people,
                |_person, _query| true,
                |person| person.name.clone(),
                cx,
            )
        });

        // Initially, first item is selected
        list.read_with(&cx, |list, _cx| {
            assert_eq!(list.selected_index, Some(0));
        });

        // Move down
        list.update(&mut cx, |list, cx| {
            list.move_selection(1, cx);
        });

        list.read_with(&cx, |list, _cx| {
            assert_eq!(list.selected_index, Some(1));
        });

        // Move down again
        list.update(&mut cx, |list, cx| {
            list.move_selection(1, cx);
        });

        list.read_with(&cx, |list, _cx| {
            assert_eq!(list.selected_index, Some(2));
        });

        // Try to move past the end (should clamp)
        list.update(&mut cx, |list, cx| {
            list.move_selection(1, cx);
        });

        list.read_with(&cx, |list, _cx| {
            assert_eq!(list.selected_index, Some(2));
        });
    }
}
```

### Key Testing Utilities

- **`TestApp::new()`**: Creates a test application context
- **`cx.new(|cx| ...)`**: Creates an entity in the test
- **`entity.read_with(&cx, |entity, cx| ...)`**: Read entity state
- **`entity.update(&mut cx, |entity, cx| ...)`**: Update entity state
- **`cx.run_until_parked()`**: Run async tasks until all are idle (useful for async operations)
- **`#[gpui::test]`**: Marks a test function for GPUI's test runner

These tests run without opening a window. They're fast and deterministic.

## Improving the Search Input

The example above uses a fake search input (just displays the query). Let's add a real one with keyboard input:

```rust
actions!(searchable_list, [Backspace, ClearSearch]);

impl<T: Clone + Send + Sync + 'static> SearchableList<T> {
    fn handle_key_down(&mut self, event: &KeyDownEvent, cx: &mut Context<Self>) {
        match event.keystroke.key.as_str() {
            "down" => self.move_selection(1, cx),
            "up" => self.move_selection(-1, cx),
            "backspace" => {
                if !self.search_query.is_empty() {
                    self.search_query.pop();
                    self.update_filter(cx);
                }
            }
            "escape" => {
                self.search_query.clear();
                self.update_filter(cx);
            }
            key if key.len() == 1 && !event.keystroke.modifiers.command => {
                self.search_query.push_str(key);
                self.update_filter(cx);
            }
            _ => {}
        }
        cx.notify();
    }
}

impl<T: Clone + Send + Sync + 'static> Render for SearchableList<T> {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .track_focus(&self.focus_handle)
            .on_key_down(cx.listener(Self::handle_key_down))
            // ... rest of rendering
    }
}
```

Now you can type to filter. Press backspace to delete characters. Press escape to clear the search.

## Packaging as a Reusable Crate

To make this component reusable across projects, extract it into a separate crate:

```
my_ui_components/
├── Cargo.toml
└── src/
    ├── lib.rs
    └── searchable_list.rs
```

In `Cargo.toml`:

```toml
[package]
name = "my_ui_components"
version = "0.1.0"
edition = "2021"

[dependencies]
gpui = { path = "../../crates/gpui" }
```

In `lib.rs`:

```rust
pub mod searchable_list;

pub use searchable_list::SearchableList;
```

Now other crates can depend on `my_ui_components` and use `SearchableList`.

## Comparison: React vs. GPUI

In React, you'd write:

```javascript
function SearchableList({ items, filterFn, renderFn }) {
    const [query, setQuery] = useState("");
    const [selectedIndex, setSelectedIndex] = useState(0);

    const filteredItems = useMemo(
        () => items.filter(item => filterFn(item, query)),
        [items, query]
    );

    return (
        <div onKeyDown={handleKeyDown}>
            <input value={query} onChange={e => setQuery(e.target.value)} />
            {filteredItems.map((item, idx) => (
                <div
                    key={idx}
                    className={idx === selectedIndex ? "selected" : ""}
                    onClick={() => setSelectedIndex(idx)}
                >
                    {renderFn(item)}
                </div>
            ))}
        </div>
    );
}
```

GPUI's version is more verbose, but you get:

1. **Compile-time type safety**: Can't pass wrong types
2. **No runtime errors**: Rust's compiler catches them
3. **Performance**: Background filtering, efficient rendering
4. **Memory safety**: No null pointer dereferences, no use-after-free

The trade-off: more upfront complexity for fewer runtime surprises.

## Summary

1. **Generics** let you build reusable components
2. **Trait objects** (`Arc<dyn Fn(...)>`) allow custom behavior
3. **Async filtering** keeps the UI responsive
4. **`TestApp`** provides a test harness for unit tests
5. **`cx.run_until_parked()`** runs async tasks in tests
6. **Packaging as a crate** makes components reusable

## What's Next

In Part 10, the final part, we'll explore how to contribute to Zed. You'll learn about Zed's architecture, how to navigate the codebase, how to build and test your changes, and how to submit a pull request. You'll also see advanced GPUI patterns used in Zed that you can apply to your own projects.

You now know how to build real components with GPUI. The last step is understanding how to work with a large, production codebase like Zed.
