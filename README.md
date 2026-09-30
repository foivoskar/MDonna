# MDonna

MDonna is a lightweight native macOS Markdown editor focused on a clean, distraction-free **live preview** experience.

It is designed as a small alternative to applications such as Obsidian when all you want is to open a normal `.md` file, edit it directly, and see the formatted result while you type — without vaults, databases, workspaces, or project-specific file structures.

MDonna combines a native Swift/AppKit shell with a CodeMirror 6 editor running inside WebKit.

---

## Current status

MDonna is under active development.

The current version is already usable as a standalone macOS application and supports opening, editing, saving, and rendering normal Markdown files.

---

## Features

### Markdown editing

- Open arbitrary `.md` and `.markdown` files
- Create new Markdown documents
- Save and Save As
- Native macOS `Open With → MDonna` support
- Finder file opening
- Unsaved-change warning when quitting
- Visible text selection
- `⌘A` selects the entire document
- Native cursor and text editing behavior
- Single-window document workflow

### Live Markdown preview

MDonna renders Markdown while keeping the document editable.

Currently supported:

- Headings
- Paragraphs
- **Bold**
- *Italic*
- ~~Strikethrough~~
- `Inline code`
- Links
- Blockquotes
- Ordered lists
- Unordered lists
- Nested lists
- Horizontal rules
- Tables
- Fenced code blocks
- Images

Markdown syntax is normally hidden when an element is being rendered and becomes visible when the element is actively edited.

For example:

```markdown
**bold text**
```

is displayed as formatted bold text, while clicking into it exposes the Markdown source for editing.

---

## Code blocks

Fenced code blocks are rendered as clean code panels.

Example:

```markdown
```python
def hello(name):
    print(f"Hello, {name}!")

hello("MDonna")
```
```

Features include:

- Language label
- Copy button
- Editable source
- Visible opening and closing fences while editing
- Syntax highlighting based on the fenced-code language

Supported syntax highlighting includes many languages provided through the CodeMirror language catalogue, including:

- Python
- Swift
- JavaScript
- TypeScript
- JSON
- Bash / shell
- HTML
- CSS
- Markdown
- and others

---

## Images

MDonna supports both remote and local Markdown images.

### Remote images

```markdown
![Example](https://example.com/image.jpg)
```

### Relative local images

```markdown
![Example](images/photo.jpg)
```

Relative image paths are resolved from the directory containing the current Markdown document.

Clicking a rendered image reveals its Markdown source so that the alt text or path can be edited.

### Drag & drop

Images can be dragged directly from Finder into an already-saved Markdown document.

MDonna automatically:

1. creates an `images/` directory next to the Markdown document,
2. copies the image there,
3. inserts the corresponding Markdown,
4. renders the image immediately.

For example:

```text
document.md
images/
    photo.jpg
```

with:

```markdown
![photo](<images/photo.jpg>)
```

### Paste images

Images copied to the macOS clipboard can also be pasted directly into MDonna.

They are stored in the same `images/` directory and the Markdown reference is generated automatically.

A document must first be saved so that MDonna knows where its associated `images/` directory should live.

---

## Architecture

MDonna currently consists of two main layers.

### Native macOS application

Written in Swift using SwiftUI, AppKit and WebKit.

Responsibilities include:

- application lifecycle
- native windows
- open/save dialogs
- Finder integration
- `.md` document handling
- unsaved-change handling
- clipboard integration
- local file access
- image import
- application packaging
- macOS application icon

### Web editor

The editing surface is implemented with CodeMirror 6.

It handles:

- Markdown parsing
- live preview decorations
- cursor interaction
- text selection
- Markdown widgets
- tables
- code blocks
- syntax highlighting
- rendered images
- drag/drop and paste events

---

## Project structure

```text
MDonna/
├── Assets/
│   └── MDonnaIcon.png
│
├── Scripts/
│   └── build-app.sh
│
├── Sources/
│   └── MDonna/
│       ├── MDonnaApp.swift
│       ├── WebEditor.swift
│       ├── WindowConfigurator.swift
│       └── Resources/
│           └── WebEditor/
│               ├── editor.js
│               ├── editor.js.map
│               ├── index.html
│               └── theme.css
│
├── WebEditor/
│   ├── package.json
│   ├── package-lock.json
│   └── src/
│       ├── editor.js
│       ├── index.html
│       └── theme.css
│
├── install/
│   └── Install MDonna.command
│
├── Package.swift
└── README.md
```

---

## Requirements

Development currently requires:

- macOS
- Xcode / Apple Swift toolchain
- Swift Package Manager
- Node.js
- npm

The application currently targets:

```text
macOS 14.0+
```

Development has primarily been performed on Apple Silicon.

---

## Building the WebEditor

The WebEditor uses npm and esbuild.

Install dependencies:

```bash
cd WebEditor
npm install
```

Build the frontend:

```bash
npm run build
```

The generated WebEditor resources are copied into:

```text
Sources/MDonna/Resources/WebEditor/
```

---

## Running during development

From the root of the repository:

```bash
swift run MDonna
```

---

## Building and installing MDonna.app

MDonna includes a build script that creates the native `.app`, generates the application icon, packages the WebEditor resources, signs the application locally, and installs it into `/Applications`.

Run:

```bash
cd /path/to/MDonna
./Scripts/build-app.sh
```

The installed application will be:

```text
/Applications/MDonna.app
```

The build process currently uses ad-hoc code signing for local use.

---

## Portable installation

The `install/` directory contains:

```text
Install MDonna.command
```

A packaged `MDonna.zip` can be placed beside it:

```text
install/
├── Install MDonna.command
└── MDonna.zip
```

The installer extracts the application and installs it into:

```text
/Applications/MDonna.app
```

`MDonna.zip` is intentionally excluded from Git because it is a generated binary artifact.

---

## Application icon

The master application artwork is stored at:

```text
Assets/MDonnaIcon.png
```

`Scripts/build-app.sh` automatically generates the required macOS `.icns` file and includes it in the application bundle.

---

## Git workflow

The main development branch is:

```text
main
```

Typical workflow:

```bash
git pull
git add .
git commit -m "Describe the change"
git push
```

Generated build output, dependencies, backups and binary installer packages are excluded through `.gitignore`.

---

## Design philosophy

MDonna is deliberately small.

The goal is not to reproduce a full knowledge-management system.

The core idea is:

> A Markdown file should remain a Markdown file.

There is no required vault, proprietary database or hidden project structure.

You should be able to open an ordinary Markdown document from anywhere on the filesystem, edit it naturally, save it, and continue using that same file with any other Markdown-compatible application.

---

## Planned development

Possible future improvements include:

- Markdown formatting keyboard shortcuts
- richer image controls
- captions and image sizing
- improved table editing
- additional Markdown syntax
- better document navigation
- application preferences
- improved multi-document handling
- release/version management
- universal macOS builds
- signed/notarized releases

---

## Name

**MDonna** is the working name of the application.

The application icon represents an abstract female figure interacting with the symbolic `</>` language of structured text and code.

---

## License

No public license has currently been assigned.

This repository is presently private and intended for personal development.
