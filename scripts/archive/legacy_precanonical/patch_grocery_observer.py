from pathlib import Path

path = Path("LifeRoute/Web/grocery-stores.js")
text = path.read_text()

old = '''  const observer = new MutationObserver(() => {
    decorateTodoCards();
    decorateGapOptions();
  });
  observer.observe(document.body, { childList: true, subtree: true });

  decorateTodoCards();
  decorateGapOptions();
'''

new = '''  // Decorate only after external DOM changes. Disconnect while decorating so
  // our own text/class/button updates do not recursively trigger the observer.
  // The previous broad observer could continuously observe its own mutations,
  // peg the WebKit JavaScript thread, make buttons stop responding, and
  // eventually cause the web-content process to be terminated.
  let observer;
  const observeDecorations = () => {
    observer.observe(document.body, { childList: true, subtree: true });
  };
  const runDecorations = () => {
    observer.disconnect();
    decorateTodoCards();
    decorateGapOptions();
    observeDecorations();
  };
  observer = new MutationObserver(runDecorations);
  runDecorations();
'''

if new in text:
    print("Grocery observer already hardened.")
elif old not in text:
    raise SystemExit("Could not patch grocery observer: expected block not found")
else:
    path.write_text(text.replace(old, new, 1))
    print("Hardened grocery MutationObserver against self-triggered render loops.")
