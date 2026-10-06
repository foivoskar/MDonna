<p align="center">
  <img src="Assets/MDonnaIcon.png" width="220" alt="MDonna icon">
</p>

MDonna
======

A lightweight Markdown editor with live visual formatting.

MDonna keeps documents as ordinary Markdown files while presenting headings, emphasis, lists, tables, code, mathematics and other Markdown elements directly inside the editor.

The project is open source and distributed using a source-first installation model.

Current version
---------------

MDonna 0.3

The current native application targets macOS 14 or later.

The editor itself is separated into a reusable WebEditor based on HTML, CSS, JavaScript, CodeMirror and KaTeX.

Installation
============

MDonna does not require a prebuilt executable download.

The application is compiled locally on the user's Mac.

No Apple Developer ID is required.

No Apple notarization is required.

The finished application receives a local ad-hoc signature.

Requirements
------------

The current macOS build requires:

    macOS 14 or later
    Apple Command Line Tools or Xcode
    Swift 6 or later
    Git
    Node.js 18 or later
    npm

Check the environment
---------------------

Clone the repository:

    git clone https://github.com/foivoskar/MDonna.git
    cd MDonna

Check whether the Mac can build MDonna:

    ./install.sh --check

Build the local installer
-------------------------

Run:

    ./install.sh

The installer performs the following operations:

    validates the local build environment
    installs the locked WebEditor dependencies
    builds the WebEditor
    compiles the native Swift application
    creates MDonna.app
    applies a local ad-hoc signature
    creates a local DMG
    verifies the DMG
    opens the finished installer

The generated installer is stored under:

    dist/

The application inside it was compiled locally from the public source code.

No prebuilt MDonna executable is downloaded.

Development installation
------------------------

Developers can build, install and launch MDonna directly with:

    ./Scripts/build-and-install.sh

This installs the locally compiled application into:

    /Applications/MDonna.app

Features
========

MDonna currently supports:

- standard Markdown files
- multiple independent document windows
- new documents with Cmd+N
- native Open, Save and Save As behaviour
- headings
- bold text
- italic text
- combined bold and italic text
- strikethrough
- lists and nested lists
- blockquotes
- links
- images
- tables
- inline code
- fenced code blocks
- programming-language syntax highlighting
- inline mathematics
- display mathematics
- KaTeX rendering
- Finder Open With integration

Markdown remains Markdown
=========================

MDonna does not use a proprietary document format.

A document edited with MDonna remains an ordinary text file such as:

    notes.md

The same file can be opened with another Markdown editor, a text editor, GitHub, documentation systems, static-site generators or command-line tools.

Mathematics
===========

Inline mathematics can be written with dollar delimiters.

For example:

    The energy is $E = mc^2$.

Display mathematics can be written with double-dollar delimiters:

    $$
    E = mc^2
    $$

LaTeX display delimiters are also supported:

    \[
    \int_0^\infty e^{-x^2}\,dx
    \]

Code
====

Fenced code blocks are supported together with language-aware syntax highlighting.

For example, a Markdown document can contain a fenced Python, Swift, JavaScript, Bash, JSON, YAML, HTML or CSS block.

Architecture
============

MDonna currently consists of two principal layers:

    Native macOS shell
            +
       WebEditor core

Native macOS shell
------------------

The native Swift application handles:

- application lifecycle
- windows
- document management
- file opening
- file saving
- macOS integration
- communication with the embedded editor

The native source is located under:

    Sources/MDonna/

WebEditor
---------

The WebEditor handles:

- Markdown editing
- live visual decorations
- code highlighting
- links
- images
- tables
- mathematics

Its source is located under:

    WebEditor/src/

The WebEditor uses:

- CodeMirror
- KaTeX
- JavaScript
- HTML
- CSS

Building
========

WebEditor
---------

Build only the WebEditor with:

    ./Scripts/build-web-editor.sh

Generated editor resources are written under:

    Sources/MDonna/Resources/WebEditor/

Native application
------------------

Build the complete application with:

    ./Scripts/build-app.sh

The result is:

    dist/MDonna.app

Local DMG
---------

Build a local installer with:

    ./Scripts/build-local-dmg.sh

The result is created under:

    dist/

Version information
-------------------

Version and build number are defined centrally in:

    Scripts/version.sh

For MDonna 0.3:

    MDONNA_VERSION="0.3"
    MDONNA_BUILD_NUMBER="1"

Repository structure
====================

    MDonna/
        Assets/
        Scripts/
            version.sh
            build-web-editor.sh
            build-app.sh
            build-and-install.sh
            build-local-dmg.sh
        Sources/
            MDonna/
        WebEditor/
            src/
            package.json
            package-lock.json
        Package.swift
        install.sh
        README.md
        LICENSE

Generated files
===============

The following are generated locally and are not source files:

    .build/
    dist/
    DerivedData/
    WebEditor/node_modules/
    Backups/

Distribution model
==================

MDonna follows a source-first distribution model.

The repository contains the source code and the tools necessary to build the application locally.

Git tags identify stable source releases.

The standard distribution process does not require downloadable prebuilt application binaries.

This avoids making Apple Developer ID membership or Apple notarization a requirement for building and using the open-source application.

Cross-platform direction
========================

The current native shell uses SwiftUI, AppKit and WebKit and therefore targets macOS.

The editor core is deliberately separated from the native shell.

Because the WebEditor uses portable web technologies, future Windows and Linux shells can reuse the same Markdown editor, mathematical rendering, tables, syntax highlighting and visual formatting engine.

The goal is to preserve one editor core while allowing platform-specific application shells where necessary.

Development workflow
====================

Synchronise the repository:

    git pull --ff-only

Install WebEditor dependencies:

    cd WebEditor
    npm ci
    cd ..

Build and install locally:

    ./Scripts/build-and-install.sh

Inspect changes:

    git status

Validate textual changes:

    git diff --check

License
========

MDonna is released under the MIT License.

Copyright © 2026 Foivos Karakostas.
