<p align="center">
  <img src="Assets/MDonnaIcon.png" width="220" alt="MDonna icon">
</p>

<h1 align="center">MDonna</h1>

<p align="center">
  <strong>A native Markdown editor for macOS.</strong><br>
  Write Markdown. See the document immediately.
</p>

---

## About MDonna

**MDonna** is a lightweight native Markdown editor for macOS.

It is built around a simple idea:

> Markdown should remain plain text, but writing it should already feel close to reading the finished document.

MDonna combines ordinary Markdown source files with an immediate, visually styled editing experience.

There is no proprietary document format. A file edited with MDonna remains a normal `.md` file that can also be opened with another Markdown editor, a text editor, GitHub, documentation systems, static-site generators, or command-line tools.

---

## Features

MDonna currently provides:

- native macOS application;
- multiple independent document windows;
- standard `.md` and `.markdown` files;
- live Markdown styling;
- headings;
- bold and italic text;
- lists;
- blockquotes;
- links;
- images;
- Markdown tables;
- inline code;
- fenced code blocks;
- syntax highlighting;
- inline mathematics;
- display mathematics;
- KaTeX rendering;
- native macOS Open / Save workflow;
- Finder **Open With** integration;
- automatic application packaging;
- DMG release generation;
- release portability validation.

---

## Multiple documents

MDonna supports multiple documents at the same time.

Use:

```text
⌘ N
```

to open a new independent document window.

Closing one document does not close the other open MDonna windows.

---

## Markdown

MDonna edits ordinary Markdown directly.

For example:

```markdown
# Heading

This is **bold text** and this is *italic text*.

> A blockquote

- First item
- Second item
- Third item

[OpenAI](https://openai.com)
```

---

## Code blocks

Fenced Markdown code blocks are supported.

For example:

````markdown
```python
def hello():
    print("Hello from MDonna")
```
````

A language identifier can be placed after the opening fence for syntax highlighting.

Examples include:

```text
python
javascript
typescript
swift
bash
json
yaml
html
css
c
cpp
java
```

---

## Mathematics

MDonna renders mathematical expressions using **KaTeX**.

### Inline mathematics

```markdown
The relation is $E = mc^2$.
```

### Display mathematics

```markdown
$$
E = mc^2
$$
```

LaTeX display delimiters are also supported:

```markdown
\[
\int_0^\infty e^{-x^2}\,dx
\]
```

More complex expressions can be written directly inside Markdown:

```markdown
\[
\nabla^2 \phi =
\frac{\partial^2 \phi}{\partial x^2}
+
\frac{\partial^2 \phi}{\partial y^2}
+
\frac{\partial^2 \phi}{\partial z^2}
\]
```

The Markdown file continues to contain the original LaTeX source.

---

## Images

Standard Markdown image syntax is supported:

```markdown
![Description](images/example.png)
```

Relative image paths are recommended when a Markdown document and its associated files should remain portable together.

For example:

```text
project/
├── notes.md
└── images/
    ├── map.png
    └── waveform.png
```

with:

```markdown
![Waveform](images/waveform.png)
```

inside `notes.md`.

---

## Tables

Standard Markdown tables are supported:

```markdown
| Station | Distance | Phase |
|---------|---------:|-------|
| ABC     | 120 km   | P     |
| XYZ     | 245 km   | S     |
```

---

# Installation

## End users

The normal installation method is the MDonna `.dmg`.

Open the disk image and drag:

```text
MDonna → Applications
```

The packaged application is self-contained.

End users do **not** need:

- Git;
- Node.js;
- npm;
- Swift;
- Swift Package Manager;
- Xcode;
- the MDonna source repository.

### Current architecture

Current development releases are built for:

```text
Apple Silicon / arm64
```

They therefore target Apple Silicon Macs.

A Universal 2 (`arm64 + x86_64`) release may be added later.

### Gatekeeper

Current local releases use ad-hoc code signing.

They are not yet distributed using Apple Developer ID signing and notarization.

On another Mac, macOS may therefore require explicit approval before the application can be opened for the first time.

Developer ID signing and Apple notarization are planned for the public distribution workflow.

---

# Building from source

## Requirements

Development currently requires:

- macOS;
- Swift;
- Swift Package Manager;
- Xcode Command Line Tools;
- Node.js;
- npm.

Check the main tools with:

```bash
swift --version
node --version
npm --version
```

---

## Clone the repository

```bash
git clone <repository-url>
cd MDonna
```

---

## Install WebEditor dependencies

The embedded editor has its own JavaScript dependencies.

Install them once with:

```bash
cd WebEditor
npm install
cd ..
```

The dependency definitions are stored in:

```text
WebEditor/package.json
WebEditor/package-lock.json
```

`WebEditor/node_modules/` is generated locally and is not stored in Git.

---

# Architecture

MDonna consists of two main layers:

```text
Native macOS application
        +
Embedded WebEditor
```

The native macOS layer handles:

- application lifecycle;
- windows;
- document management;
- opening files;
- saving files;
- macOS integration;
- communication with the embedded editor.

The WebEditor handles:

- Markdown editing;
- visual Markdown decorations;
- code highlighting;
- links;
- images;
- tables;
- mathematical rendering.

---

# WebEditor development

The WebEditor sources are located under:

```text
WebEditor/src/
```

After modifying them, rebuild the WebEditor with:

```bash
cd WebEditor
npm run build
cd ..
```

The generated resources are then packaged into the native application.

---

# Build scripts

MDonna separates development, installation, release packaging and release validation.

## Build the application

```bash
./Scripts/build-app.sh
```

This creates:

```text
dist/MDonna.app
```

The script packages the release executable, resources, WebEditor files, application metadata, Markdown document registration and application icon.

It also performs local ad-hoc code signing.

---

## Build and install locally

For normal development:

```bash
./Scripts/build-and-install.sh
```

This performs:

```text
build
  ↓
MDonna.app
  ↓
install into /Applications
  ↓
launch
```

The resulting installed application is:

```text
/Applications/MDonna.app
```

---

## Build a distributable DMG

Create a release disk image with:

```bash
./Scripts/build-release.sh
```

The result is written under:

```text
dist/
```

For example:

```text
MDonna-0.1-macOS-arm64.dmg
```

The DMG contains the complete application and a standard macOS drag-to-Applications installation window.

The DMG itself is sufficient for installation on a compatible Mac. The recipient does not need the MDonna repository or development dependencies.

---

## Validate a release

Before distributing a DMG, run:

```bash
./Scripts/check-release.sh
```

The release checker verifies:

- disk image integrity;
- application bundle structure;
- executable architecture;
- code signature;
- Gatekeeper status;
- dynamic-library dependencies;
- runtime search paths;
- hard-coded development-machine paths;
- symlinks;
- accidental development artefacts;
- execution from an unrelated temporary directory.

A healthy build should finish with:

```text
FAIL : 0
```

Warnings related to ad-hoc signing, Apple notarization or the absence of Intel support are currently expected.

---

# Repository structure

The main repository structure is:

```text
MDonna/
├── Assets/
│   └── MDonnaIcon.png
│
├── Scripts/
│   ├── build-app.sh
│   ├── build-and-install.sh
│   ├── build-release.sh
│   └── check-release.sh
│
├── Sources/
│   └── MDonna/
│       ├── MDonnaApp.swift
│       └── Resources/
│           └── WebEditor/
│
├── WebEditor/
│   ├── src/
│   │   ├── editor.js
│   │   ├── index.html
│   │   └── theme.css
│   │
│   ├── package.json
│   └── package-lock.json
│
├── Package.swift
└── README.md
```

---

# Generated files

The following directories and files are generated locally and should not be treated as source code:

```text
.build/
dist/
WebEditor/node_modules/
Backups/
install/MDonna.zip
```

They can be regenerated from the repository source and build scripts.

Release `.dmg` files are also build artefacts and do not need to be committed to the source repository.

---

# Typical development workflow

Synchronise the repository:

```bash
git pull --rebase
```

Make the desired changes.

If the WebEditor changed:

```bash
cd WebEditor
npm run build
cd ..
```

Build and install:

```bash
./Scripts/build-and-install.sh
```

Inspect changes:

```bash
git status
```

Commit:

```bash
git add .
git commit -m "Describe the change"
```

Push:

```bash
git push
```

---

# Release workflow

Build the release:

```bash
./Scripts/build-release.sh
```

Validate it:

```bash
./Scripts/check-release.sh
```

The current release pipeline is:

```text
source
  ↓
WebEditor build
  ↓
Swift release build
  ↓
MDonna.app
  ↓
code signing
  ↓
DMG
  ↓
release validation
  ↓
distribution
```

Future public releases are intended to add:

```text
Developer ID signing
        ↓
Apple notarization
        ↓
stapling
        ↓
public distribution
```

---

# Design philosophy

## Markdown stays Markdown

MDonna does not replace Markdown with a proprietary document format.

The document stored on disk remains readable plain text.

## Source and presentation belong together

Markdown is useful because its structure is explicit and portable.

MDonna keeps that structure while providing immediate visual interpretation.

## Opening another document should be trivial

Creating another document should require nothing more than:

```text
⌘ N
```

Multiple documents can remain open independently.

## The application should remain focused

MDonna is not intended to become:

- a full IDE;
- a cloud platform;
- a proprietary knowledge-management system;
- a closed document ecosystem.

It is a focused native Markdown editor.

---

# Development status

MDonna is under active development.

Current areas of development include:

- Markdown editing and rendering;
- mathematical expressions;
- code blocks and syntax highlighting;
- macOS document integration;
- multiple document windows;
- application packaging;
- DMG distribution;
- release validation.

Future distribution work includes:

- Developer ID signing;
- Apple notarization;
- possible Universal 2 releases.

---

<p align="center">
  <strong>MDonna</strong><br>
  Plain Markdown in. Readable document immediately.
</p>
