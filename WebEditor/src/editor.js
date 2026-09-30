import {
    EditorState,
    StateField
} from "@codemirror/state";

import {
    EditorView,
    Decoration,
    ViewPlugin,
    WidgetType,
    keymap,
    drawSelection
} from "@codemirror/view";

import {
    defaultKeymap,
    history,
    historyKeymap,
    indentWithTab,
    selectAll
} from "@codemirror/commands";

import {
    searchKeymap
} from "@codemirror/search";

import {
    markdown,
    markdownLanguage
} from "@codemirror/lang-markdown";

import {
    GFM
} from "@lezer/markdown";

import katex from "katex";




import {
    HighlightStyle as MDonnaHighlightStyle,
    syntaxHighlighting as mdonnaSyntaxHighlighting
} from "@codemirror/language";

import {
    languages as mdonnaCodeLanguages
} from "@codemirror/language-data";

import {
    tags as mdonnaTags
} from "@lezer/highlight";



// ============================================================
// Programming-language syntax highlighting
// ============================================================

const mdonnaSyntaxHighlightStyle =
    MDonnaHighlightStyle.define([

        {
            tag:
                mdonnaTags.keyword,

            color:
                "var(--syntax-keyword)"
        },

        {
            tag: [
                mdonnaTags.atom,
                mdonnaTags.bool,
                mdonnaTags.number
            ],

            color:
                "var(--syntax-number)"
        },

        {
            tag: [
                mdonnaTags.string,
                mdonnaTags.regexp
            ],

            color:
                "var(--syntax-string)"
        },

        {
            tag:
                mdonnaTags.comment,

            color:
                "var(--syntax-comment)",

            fontStyle:
                "italic"
        },

        {
            tag:
                mdonnaTags.variableName,

            color:
                "var(--syntax-variable)"
        },

        {
            tag:
                mdonnaTags.function(
                    mdonnaTags.variableName
                ),

            color:
                "var(--syntax-function)"
        },

        {
            tag: [
                mdonnaTags.typeName,
                mdonnaTags.className
            ],

            color:
                "var(--syntax-type)"
        },

        {
            tag:
                mdonnaTags.propertyName,

            color:
                "var(--syntax-property)"
        },

        {
            tag:
                mdonnaTags.operator,

            color:
                "var(--syntax-operator)"
        },

        {
            tag:
                mdonnaTags.meta,

            color:
                "var(--syntax-meta)"
        },

        {
            tag:
                mdonnaTags.invalid,

            color:
                "var(--syntax-invalid)",

            textDecoration:
                "underline"
        }
    ]);


const mdonnaSyntaxHighlightExtension =
    mdonnaSyntaxHighlighting(
        mdonnaSyntaxHighlightStyle
    );

let applyingNativeUpdate = false;

/*
 Relative images are resolved from the directory containing
 the currently-open .md file.
*/
let documentBaseURL = null;


/*
 Native image imports are asynchronous because Swift first
 copies the image into the document's images/ directory.
*/
const pendingImageImports =
    new Map();

let nextImageImportID =
    1;


window.addEventListener("error", event => {

    sendToNative({
        type: "log",
        message:
            "JS ERROR: " +
            (event.message || "Unknown error") +
            " @ " +
            (event.filename || "?") +
            ":" +
            (event.lineno || "?")
    });
});

window.addEventListener(
    "unhandledrejection",
    event => {

        sendToNative({
            type: "log",
            message:
                "JS PROMISE ERROR: " +
                String(event.reason)
        });
    }
);


// ============================================================
// Native bridge
// ============================================================

function sendToNative(message) {

    window.webkit
        ?.messageHandlers
        ?.mdonna
        ?.postMessage(message);
}


function sendMarkdownToNative(markdownText) {

    if (applyingNativeUpdate) {
        return;
    }

    sendToNative({
        type: "change",
        markdown: markdownText
    });
}


function openExternalLink(url) {

    sendToNative({
        type: "openLink",
        url
    });
}


// ============================================================
// General helpers
// ============================================================

function selectionTouches(
    state,
    from,
    to
) {

    return state.selection.ranges.some(
        selection => {

            if (selection.empty) {

                return (
                    selection.from >= from &&
                    selection.from <= to
                );
            }

            return (
                selection.from <= to &&
                selection.to >= from
            );
        }
    );
}


function selectionOverlaps(
    state,
    from,
    to
) {

    return state.selection.ranges.some(
        range => {

            if (range.empty) {
                return false;
            }

            return (
                range.from < to &&
                range.to > from
            );
        }
    );
}


function rangesOverlap(
    aFrom,
    aTo,
    bFrom,
    bTo
) {

    return (
        aFrom < bTo &&
        aTo > bFrom
    );
}


function insideAnyRange(
    from,
    to,
    ranges
) {

    return ranges.some(
        range =>
            rangesOverlap(
                from,
                to,
                range.from,
                range.to
            )
    );
}



function imageFilesFromTransfer(
    transfer
) {

    if (!transfer) {
        return [];
    }


    const result = [];
    const seen = new Set();


    /*
     Finder drag/drop usually exposes files directly.
    */

    for (
        const file
        of Array.from(
            transfer.files || []
        )
    ) {

        if (
            file.type
                .toLowerCase()
                .startsWith("image/")
        ) {

            const key =
                `${file.name}:${file.size}:${file.type}`;

            if (!seen.has(key)) {

                seen.add(key);
                result.push(file);
            }
        }
    }


    /*
     macOS clipboard often exposes an image as an item rather
     than through the files collection.
    */

    for (
        const item
        of Array.from(
            transfer.items || []
        )
    ) {

        if (
            item.kind !== "file"
            ||
            !item.type
                .toLowerCase()
                .startsWith("image/")
        ) {

            continue;
        }


        const file =
            item.getAsFile();

        if (!file) {
            continue;
        }


        const key =
            `${file.name}:${file.size}:${file.type}`;

        if (!seen.has(key)) {

            seen.add(key);
            result.push(file);
        }
    }


    return result;
}


function fileAsDataURL(
    file
) {

    return new Promise(
        (resolve, reject) => {

            const reader =
                new FileReader();


            reader.onload =
                () => {

                    resolve(
                        reader.result
                    );
                };


            reader.onerror =
                () => {

                    reject(
                        reader.error
                        || new Error(
                            "Could not read image."
                        )
                    );
                };


            reader.readAsDataURL(
                file
            );
        }
    );
}


async function requestNativeImageImport(
    file,
    position
) {

    if (!documentBaseURL) {

        window.webkit
            .messageHandlers
            .mdonna
            .postMessage({
                type:
                    "imageImportNeedsSavedDocument"
            });

        return null;
    }


    /*
     Keep bridge messages at a sensible size.
    */

    const maximumSize =
        25 * 1024 * 1024;

    if (
        file.size >
        maximumSize
    ) {

        window.webkit
            .messageHandlers
            .mdonna
            .postMessage({

                type:
                    "imageImportError",

                message:
                    "The image is larger than 25 MB."
            });

        return null;
    }


    const dataURL =
        await fileAsDataURL(
            file
        );


    const requestID =
        `image-${nextImageImportID++}`;


    return new Promise(
        resolve => {

            pendingImageImports.set(
                requestID,
                resolve
            );


            window.webkit
                .messageHandlers
                .mdonna
                .postMessage({

                    type:
                        "importImage",

                    requestID,

                    filename:
                        file.name || "",

                    mimeType:
                        file.type || "",

                    dataURL,

                    position
                });
        }
    );
}


async function importTransferredImages(
    files,
    initialPosition
) {

    let position =
        initialPosition;


    for (
        const file
        of files
    ) {

        try {

            const result =
                await requestNativeImageImport(
                    file,
                    position
                );


            if (
                result
                &&
                Number.isInteger(
                    result.position
                )
            ) {

                position =
                    result.position;
            }

        } catch (error) {

            console.error(
                "MDonna image import:",
                error
            );
        }
    }
}


/*
 CodeMirror owns ordinary text paste/drop.

 We intercept the event only when actual image files are
 present. Normal text copy/paste therefore behaves exactly as
 before.
*/

const imageTransferHandlers =
    EditorView.domEventHandlers({

        paste(
            event,
            view
        ) {

            const files =
                imageFilesFromTransfer(
                    event.clipboardData
                );


            if (
                files.length === 0
            ) {

                return false;
            }


            event.preventDefault();


            importTransferredImages(
                files,
                view.state
                    .selection
                    .main
                    .from
            );


            return true;
        },


        dragover(
            event
        ) {

            const types =
                Array.from(
                    event.dataTransfer
                        ?.types
                    || []
                );


            if (
                !types.includes(
                    "Files"
                )
            ) {

                return false;
            }


            event.preventDefault();

            return true;
        },


        drop(
            event,
            view
        ) {

            const files =
                imageFilesFromTransfer(
                    event.dataTransfer
                );


            if (
                files.length === 0
            ) {

                return false;
            }


            event.preventDefault();


            const position =
                view.posAtCoords({

                    x:
                        event.clientX,

                    y:
                        event.clientY

                })
                ??
                view.state
                    .selection
                    .main
                    .from;


            importTransferredImages(
                files,
                position
            );


            return true;
        }
    });


function resolveImageURL(
    source
) {

    const value =
        source.trim();


    /*
     Network/data images can be loaded directly by WKWebView.
    */

    if (
        /^(https?:|data:|blob:)/i
            .test(value)
    ) {

        return value;
    }


    try {

        let fileURL;


        /*
         Absolute filesystem path.
        */

        if (
            value.startsWith("/")
        ) {

            fileURL =
                new URL(
                    "file://" +
                    value
                );

        } else {

            /*
             Relative images need a saved/open Markdown
             document so that we know its directory.
            */

            if (!documentBaseURL) {
                return null;
            }

            fileURL =
                new URL(
                    value,
                    documentBaseURL
                );
        }


        const path =
            decodeURIComponent(
                fileURL.pathname
            );


        /*
         Arbitrary local files cannot be loaded directly by
         this WKWebView's file-origin sandbox. Pass them
         through our native mdonna-file:// scheme instead.
        */

        return (
            "mdonna-file://local?path=" +
            encodeURIComponent(path)
        );

    } catch {

        return null;
    }
}


function escapedText(
    text
) {

    const span =
        document.createElement("span");

    span.textContent =
        text;

    return span;
}


// ============================================================
// Widgets
// ============================================================

class ListMarkerWidget extends WidgetType {

    constructor(
        marker,
        level,
        selected = false
    ) {

        super();

        this.marker =
            marker;

        this.level =
            level;

        this.selected =
            selected;
    }


    eq(other) {

        return (
            other.marker === this.marker &&
            other.level === this.level &&
            other.selected === this.selected
        );
    }


    toDOM() {

        const span =
            document.createElement("span");

        const numbered =
            /^\d/.test(
                this.marker
            );

        if (numbered) {

            span.className =
                "md-list-marker md-list-marker-number";

            span.textContent =
                this.marker;

        } else {

            const visualLevel =
                this.level % 3;

            span.className =
                "md-list-marker md-list-marker-bullet " +
                `md-list-level-${visualLevel}`;

            /*
             The actual marker is drawn entirely in CSS.
             No font glyphs, so its weight and shape are
             independent from the document font.
            */

            span.textContent = "";
        }

        /*
         Real indentation belongs to the marker widget itself.
         This avoids relying on CodeMirror line-decoration
         custom properties, which WebKit was not applying
         reliably in our previous version.
        */

        span.style.marginLeft =
            `${this.level * 28}px`;

        if (this.selected) {
            span.classList.add(
                "md-selected-widget"
            );
        }

        return span;
    }


    ignoreEvent() {
        return true;
    }
}


class HorizontalRuleWidget extends WidgetType {

    constructor(
        selected = false
    ) {

        super();

        this.selected =
            selected;
    }


    eq(other) {

        return (
            other.selected ===
            this.selected
        );
    }


    toDOM() {

        const wrapper =
            document.createElement("div");

        wrapper.className =
            "md-horizontal-rule";

        if (this.selected) {
            wrapper.classList.add(
                "md-selected-widget"
            );
        }

        return wrapper;
    }


    ignoreEvent() {
        return true;
    }
}


class LinkWidget extends WidgetType {

    constructor(
        label,
        url,
        selected = false
    ) {

        super();

        this.label =
            label;

        this.url =
            url;

        this.selected =
            selected;
    }


    eq(other) {

        return (
            other.label === this.label &&
            other.url === this.url &&
            other.selected === this.selected
        );
    }


    toDOM() {

        const link =
            document.createElement("a");

        link.className =
            "md-link";

        link.href =
            this.url;

        link.textContent =
            this.label;

        if (this.selected) {
            link.classList.add(
                "md-selected-widget"
            );
        }

        link.addEventListener(
            "click",
            event => {

                event.preventDefault();
                event.stopPropagation();

                openExternalLink(
                    this.url
                );
            }
        );

        return link;
    }


    ignoreEvent() {
        return false;
    }
}



// ============================================================
// MDonna KaTeX Math Widget
// ============================================================

class MathWidget extends WidgetType {

    constructor(
        source,
        displayMode,
        sourceFrom,
        selected = false
    ) {

        super();

        this.source =
            source;

        this.displayMode =
            displayMode;

        this.sourceFrom =
            sourceFrom;

        this.selected =
            selected;
    }


    eq(other) {

        return (
            other.source === this.source &&
            other.displayMode === this.displayMode &&
            other.sourceFrom === this.sourceFrom &&
            other.selected === this.selected
        );
    }


    get estimatedHeight() {

        return this.displayMode
            ? 58
            : 24;
    }


    toDOM(view) {

        const wrapper =
            document.createElement(
                "span"
            );

        wrapper.className =
            this.displayMode
            ? "md-math md-math-block"
            : "md-math md-math-inline";


        if (this.selected) {

            wrapper.classList.add(
                "md-selected-widget"
            );
        }


        /*
         Clicking rendered mathematics reveals its
         original Markdown/LaTeX source by placing
         the cursor just inside the opening delimiter.
        */

        wrapper.addEventListener(
            "mousedown",
            event => {

                event.preventDefault();
                event.stopPropagation();

                const delimiterLength =
                    this.displayMode
                    ? 2
                    : 1;

                const anchor =
                    Math.min(
                        this.sourceFrom +
                            delimiterLength,
                        view.state.doc.length
                    );

                view.dispatch({

                    selection: {
                        anchor
                    },

                    scrollIntoView:
                        true
                });

                view.focus();
            }
        );


        katex.render(
            this.source,
            wrapper,
            {
                displayMode:
                    this.displayMode,

                throwOnError:
                    false,

                strict:
                    "ignore",

                trust:
                    false,

                output:
                    "htmlAndMathml"
            }
        );


        return wrapper;
    }


    ignoreEvent() {

        return false;
    }
}


// ============================================================
// Inline Markdown renderer for widgets
// ============================================================

function appendInlineMarkdown(
    parent,
    source
) {

    const pattern =
        /((?<!\\)\$(?!\$)[^$\n]+?(?<!\\)\$(?!\$)|\*\*.+?\*\*|__.+?__|~~.+?~~|`[^`\n]+`|\*[^*\n]+?\*|_[^_\n]+?_|!\[[^\]]*]\([^)]+\)|\[[^\]]+]\([^)]+\))/g;

    let position = 0;

    for (
        const match
        of source.matchAll(pattern)
    ) {

        const index =
            match.index;

        if (index > position) {

            parent.appendChild(
                escapedText(
                    source.slice(
                        position,
                        index
                    )
                )
            );
        }

        const token =
            match[0];

        if (
            token.startsWith("$") &&
            token.endsWith("$")
        ) {

            const math =
                document.createElement(
                    "span"
                );

            math.className =
                "md-math md-math-inline";

            katex.render(
                token.slice(
                    1,
                    -1
                ),
                math,
                {
                    displayMode:
                        false,

                    throwOnError:
                        false,

                    strict:
                        "ignore",

                    trust:
                        false,

                    output:
                        "htmlAndMathml"
                }
            );

            parent.appendChild(
                math
            );

        } else if (
            token.startsWith("**") &&
            token.endsWith("**")
        ) {

            const strong =
                document.createElement("strong");

            appendInlineMarkdown(
                strong,
                token.slice(2, -2)
            );

            parent.appendChild(
                strong
            );

        } else if (
            token.startsWith("__") &&
            token.endsWith("__")
        ) {

            const strong =
                document.createElement("strong");

            appendInlineMarkdown(
                strong,
                token.slice(2, -2)
            );

            parent.appendChild(
                strong
            );

        } else if (
            token.startsWith("~~") &&
            token.endsWith("~~")
        ) {

            const del =
                document.createElement("del");

            appendInlineMarkdown(
                del,
                token.slice(2, -2)
            );

            parent.appendChild(
                del
            );

        } else if (
            token.startsWith("`")
        ) {

            const code =
                document.createElement("code");

            code.className =
                "md-inline-code";

            code.textContent =
                token.slice(1, -1);

            parent.appendChild(
                code
            );

        } else if (
            token.startsWith("![")
        ) {

            const imageMatch =
                token.match(
                    /^!\[([^\]]*)]\(([^)\s]+)(?:\s+["'][^"']*["'])?\)$/
                );

            if (imageMatch) {

                const label =
                    document.createElement("span");

                label.className =
                    "md-image-placeholder";

                label.textContent =
                    imageMatch[1]
                    || "Image";

                parent.appendChild(
                    label
                );
            }

        } else if (
            token.startsWith("[")
        ) {

            const linkMatch =
                token.match(
                    /^\[([^\]]+)]\(([^)\s]+)(?:\s+["'][^"']*["'])?\)$/
                );

            if (linkMatch) {

                const link =
                    document.createElement("a");

                link.className =
                    "md-link";

                link.href =
                    linkMatch[2];

                link.textContent =
                    linkMatch[1];

                link.addEventListener(
                    "click",
                    event => {

                        event.preventDefault();
                        event.stopPropagation();

                        openExternalLink(
                            linkMatch[2]
                        );
                    }
                );

                parent.appendChild(
                    link
                );
            }

        } else {

            const em =
                document.createElement("em");

            appendInlineMarkdown(
                em,
                token.slice(1, -1)
            );

            parent.appendChild(
                em
            );
        }

        position =
            index +
            token.length;
    }

    if (position < source.length) {

        parent.appendChild(
            escapedText(
                source.slice(position)
            )
        );
    }
}


// ============================================================
// Code block widget
// ============================================================

function copyText(
    text,
    button
) {

    sendToNative({
        type: "copy",
        text
    });

    const previous =
        button.textContent;

    button.textContent =
        "Copied";

    setTimeout(
        () => {

            button.textContent =
                previous;

        },
        900
    );
}


class CodeHeaderWidget extends WidgetType {

    constructor(
        language,
        code,
        selected = false
    ) {

        super();

        this.language =
            language;

        this.code =
            code;

        this.selected =
            selected;
    }


    eq(other) {

        return (
            other.language === this.language &&
            other.code === this.code &&
            other.selected === this.selected
        );
    }


    get estimatedHeight() {

        return 52;
    }


    toDOM() {

        const slot =
            document.createElement("div");

        slot.className =
            "md-code-header-slot";


        const header =
            document.createElement("div");

        header.className =
            "md-code-header md-code-header-widget";


        const language =
            document.createElement("span");

        language.className =
            "md-code-language";

        language.textContent =
            this.language || "Code";


        const copy =
            document.createElement("button");

        copy.type =
            "button";

        copy.className =
            "md-copy-button";

        copy.textContent =
            "Copy";


        copy.addEventListener(
            "mousedown",
            event => {

                event.preventDefault();
                event.stopPropagation();
            }
        );


        copy.addEventListener(
            "click",
            event => {

                event.preventDefault();
                event.stopPropagation();

                copyText(
                    this.code,
                    copy
                );
            }
        );


        header.append(
            language,
            copy
        );

        if (this.selected) {
            slot.classList.add(
                "md-selected-widget"
            );
        }

        slot.appendChild(
            header
        );

        return slot;
    }


    ignoreEvent() {

        return false;
    }
}


// ============================================================
// Image widget
// ============================================================

class ImageWidget extends WidgetType {

    constructor(
        alt,
        source,
        resolvedSource,
        title,
        sourceFrom,
        block,
        selected = false
    ) {

        super();

        this.alt =
            alt;

        this.source =
            source;

        this.resolvedSource =
            resolvedSource;

        this.title =
            title;

        this.sourceFrom =
            sourceFrom;

        this.block =
            block;

        this.selected =
            selected;
    }


    eq(other) {

        return (
            other.alt === this.alt &&
            other.source === this.source &&
            other.resolvedSource ===
                this.resolvedSource &&
            other.title === this.title &&
            other.sourceFrom ===
                this.sourceFrom &&
            other.block === this.block &&
            other.selected ===
                this.selected
        );
    }


    get estimatedHeight() {

        return this.block
            ? 280
            : 24;
    }


    toDOM(view) {

        const wrapper =
            document.createElement(
                this.block
                ? "div"
                : "span"
            );

        wrapper.className =
            this.block
            ? "md-image-slot md-image-block-slot"
            : "md-image-slot md-image-inline-slot";


        if (this.selected) {

            wrapper.classList.add(
                "md-selected-widget"
            );
        }


        /*
         Clicking the rendered image reveals the Markdown
         source so the path / alt text can be edited.
        */

        wrapper.addEventListener(
            "mousedown",
            event => {

                event.preventDefault();
                event.stopPropagation();

                const position =
                    Math.min(
                        this.sourceFrom + 2,
                        view.state.doc.length
                    );

                view.dispatch({

                    selection: {
                        anchor: position
                    },

                    scrollIntoView:
                        true
                });

                view.focus();
            }
        );


        if (!this.resolvedSource) {

            const placeholder =
                document.createElement(
                    "span"
                );

            placeholder.className =
                "md-image-error";

            placeholder.textContent =
                this.alt
                || "Local image — save the Markdown file first";

            wrapper.appendChild(
                placeholder
            );

            return wrapper;
        }


        const image =
            document.createElement(
                "img"
            );

        image.className =
            this.block
            ? "md-image md-image-block"
            : "md-image md-image-inline";

        image.src =
            this.resolvedSource;

        image.alt =
            this.alt || "";

        if (this.title) {

            image.title =
                this.title;
        }


        /*
         Image dimensions are not known when CodeMirror first
         constructs the widget. Request a fresh measurement
         when loading completes.
        */

        image.addEventListener(
            "load",
            () => {

                view.requestMeasure();
            }
        );


        image.addEventListener(
            "error",
            () => {

                image.remove();

                const error =
                    document.createElement(
                        "span"
                    );

                error.className =
                    "md-image-error";

                error.textContent =
                    this.alt
                    ? `Could not load image: ${this.alt}`
                    : `Could not load image: ${this.source}`;

                wrapper.appendChild(
                    error
                );

                view.requestMeasure();
            }
        );


        wrapper.appendChild(
            image
        );

        return wrapper;
    }


    ignoreEvent() {

        return false;
    }
}


// ============================================================
// Table widget
// ============================================================

function parseTableCells(
    line
) {

    let value =
        line.trim();

    if (
        value.startsWith("|")
    ) {

        value =
            value.slice(1);
    }

    if (
        value.endsWith("|")
    ) {

        value =
            value.slice(0, -1);
    }

    return value
        .split("|")
        .map(
            cell =>
                cell.trim()
        );
}


function parseTableAlignment(
    separatorLine
) {

    return parseTableCells(
        separatorLine
    )
    .map(
        cell => {

            const trimmed =
                cell.trim();

            const left =
                trimmed.startsWith(":");

            const right =
                trimmed.endsWith(":");

            if (
                left &&
                right
            ) {

                return "center";
            }

            if (right) {

                return "right";
            }

            return "left";
        }
    );
}


class TableWidget extends WidgetType {

    constructor(
        rows,
        alignments,
        selected = false
    ) {

        super();

        this.rows =
            rows;

        this.alignments =
            alignments;

        this.selected =
            selected;
    }


    eq(other) {

        return (
            JSON.stringify(other.rows)
                ===
            JSON.stringify(this.rows)
            &&
            JSON.stringify(other.alignments)
                ===
            JSON.stringify(this.alignments)
            &&
            other.selected ===
                this.selected
        );
    }


    get estimatedHeight() {

        return (
            32 +
            this.rows.length * 38
        );
    }


    toDOM() {

        const slot =
            document.createElement("div");

        slot.className =
            "md-table-slot";


        const wrapper =
            document.createElement("div");

        wrapper.className =
            "md-table-wrapper";


        const table =
            document.createElement("table");

        table.className =
            "md-table";


        this.rows.forEach(
            (row, rowIndex) => {

                const tr =
                    document.createElement("tr");

                row.forEach(
                    (cell, columnIndex) => {

                        const element =
                            document.createElement(
                                rowIndex === 0
                                ? "th"
                                : "td"
                            );

                        element.style.textAlign =
                            this.alignments[columnIndex]
                            || "left";

                        appendInlineMarkdown(
                            element,
                            cell
                        );

                        tr.appendChild(
                            element
                        );
                    }
                );

                table.appendChild(
                    tr
                );
            }
        );


        wrapper.appendChild(
            table
        );

        if (this.selected) {
            slot.classList.add(
                "md-selected-widget"
            );
        }

        slot.appendChild(
            wrapper
        );

        return slot;
    }


    ignoreEvent() {
        return false;
    }
}


// ============================================================
// Decoration engine
// ============================================================

function buildDecorations(
    state
) {

    const text =
        state.doc.toString();

    if (!window.__mdonnaPreviewLogged) {

        window.__mdonnaPreviewLogged =
            true;

        sendToNative({
            type: "log",
            message:
                "LIVE PREVIEW ACTIVE; document length = "
                + text.length
        });
    }

    const decorations = [];
    const protectedRanges = [];

    if (
        text.length > 0 &&
        !window.__mdonnaNonEmptyPreviewLogged
    ) {

        window.__mdonnaNonEmptyPreviewLogged = true;

        sendToNative({
            type: "log",
            message:
                "LIVE PREVIEW REBUILD; document length = "
                + text.length
        });
    }


    // --------------------------------------------------------
    // Fenced code blocks
    // --------------------------------------------------------

    const codePattern =
        /^```([A-Za-z0-9_+\-]*)[^\n]*\n([\s\S]*?)^```[ \t]*$/gm;

    for (
        const match
        of text.matchAll(codePattern)
    ) {

        const from =
            match.index;

        const matchTo =
            from +
            match[0].length;

        protectedRanges.push({
            from,
            to: matchTo
        });


        const language =
            match[1] || "";

        const code =
            match[2]
                .replace(/\n$/, "");


        /*
         Opening fence line.
        */

        const openingLine =
            state.doc.lineAt(
                from
            );


        /*
         First character of actual code.
        */

        const contentFrom =
            openingLine.to < state.doc.length
            ? openingLine.to + 1
            : openingLine.to;


        /*
         The regex capture ends exactly where the
         closing ``` line begins.
        */

        const contentTo =
            contentFrom +
            match[2].length;


        const closingPosition =
            Math.min(
                contentTo,
                Math.max(
                    0,
                    state.doc.length - 1
                )
            );

        const closingLine =
            state.doc.lineAt(
                closingPosition
            );


        /*
         When the cursor enters the code block,
         reveal the complete Markdown source:
         opening fence, language and closing fence.
        */

        const active =
            selectionTouches(
                state,
                from,
                matchTo
            );


        /*
         Outside the block we hide the fences and show
         the rendered header.

         Inside the block we reveal the real Markdown
         fence lines so they can be edited.
        */

        if (active) {

            decorations.push(
                Decoration.line({
                    class:
                        "md-code-fence-source md-code-fence-source-open"
                })
                .range(
                    openingLine.from
                )
            );

            decorations.push(
                Decoration.line({
                    class:
                        "md-code-fence-source md-code-fence-source-close"
                })
                .range(
                    closingLine.from
                )
            );

        } else {

            decorations.push(
                Decoration.line({
                    class:
                        "md-code-fence-hidden"
                })
                .range(
                    openingLine.from
                )
            );

            decorations.push(
                Decoration.line({
                    class:
                        "md-code-fence-hidden"
                })
                .range(
                    closingLine.from
                )
            );
        }


        /*
         Collect real code lines.
        */

        const bodyLines = [];

        let position =
            contentFrom;

        while (
            position <
            contentTo
        ) {

            const line =
                state.doc.lineAt(
                    position
                );

            if (
                line.from >=
                closingLine.from
            ) {

                break;
            }

            bodyLines.push(
                line
            );

            if (
                line.to >=
                state.doc.length
            ) {

                break;
            }

            position =
                line.to + 1;
        }


        const headerPosition =
            bodyLines.length > 0
            ? bodyLines[0].from
            : closingLine.from;


        /*
         Real block widget for header only.
         It does not replace any code text.
        */

        if (!active) {

            decorations.push(
                Decoration.widget({
                    widget:
                        new CodeHeaderWidget(
                            language,
                            code,
                            selectionOverlaps(
                                state,
                                from,
                                matchTo
                            )
                        ),
                    block: true,
                    side: -1
                })
                .range(
                    headerPosition
                )
            );
        }


        /*
         Style each actual CodeMirror line.
         Cursor selection therefore remains native.
        */

        bodyLines.forEach(
            (line, index) => {

                let className =
                    active
                    ? "md-code-line md-code-active-line"
                    : "md-code-line";

                if (
                    !active &&
                    index === 0
                ) {

                    className +=
                        " md-code-first-line";
                }

                if (
                    !active &&
                    index ===
                        bodyLines.length - 1
                ) {

                    className +=
                        " md-code-last-line";
                }


                decorations.push(
                    Decoration.line({
                        class:
                            className
                    })
                    .range(
                        line.from
                    )
                );
            }
        );
    }


    // --------------------------------------------------------
    // Tables
    // --------------------------------------------------------

    const lines = [];

    for (
        let lineNumber = 1;
        lineNumber <=
            state.doc.lines;
        lineNumber++
    ) {

        const line =
            state.doc.line(
                lineNumber
            );

        lines.push({
            number: lineNumber,
            from: line.from,
            to: line.to,
            text: line.text
        });
    }


    const separatorPattern =
        /^\s*\|?\s*:?-{3,}:?\s*(?:\|\s*:?-{3,}:?\s*)+\|?\s*$/;


    for (
        let index = 1;
        index < lines.length;
        index++
    ) {

        const separator =
            lines[index];

        if (
            !separatorPattern.test(
                separator.text
            )
        ) {

            continue;
        }


        const header =
            lines[index - 1];

        if (
            insideAnyRange(
                header.from,
                separator.to,
                protectedRanges
            )
        ) {

            continue;
        }


        const rows = [
            parseTableCells(
                header.text
            )
        ];


        const alignments =
            parseTableAlignment(
                separator.text
            );


        let lastLine =
            separator;

        let nextIndex =
            index + 1;


        while (
            nextIndex <
            lines.length
        ) {

            const candidate =
                lines[nextIndex];

            if (
                !candidate.text.includes("|")
                ||
                candidate.text.trim() === ""
            ) {

                break;
            }

            rows.push(
                parseTableCells(
                    candidate.text
                )
            );

            lastLine =
                candidate;

            nextIndex += 1;
        }


        let from =
            header.from;

        let to =
            lastLine.to;

        if (
            text[to] === "\n"
        ) {

            to += 1;
        }


        protectedRanges.push({
            from,
            to
        });


        if (
            !selectionTouches(
                state,
                from,
                to
            )
        ) {

            decorations.push(
                Decoration.replace({
                    widget:
                        new TableWidget(
                            rows,
                            alignments,
                            selectionOverlaps(
                                state,
                                from,
                                to
                            )
                        ),
                    block: true
                })
                .range(
                    from,
                    to
                )
            );
        }


        index =
            nextIndex - 1;
    }


    // --------------------------------------------------------

    // --------------------------------------------------------
    // MDonna KaTeX math decorations
    // --------------------------------------------------------

    /*
     Display mathematics:

         $$
         E = mc^2
         $$

     This pass runs after fenced code blocks have already
     populated protectedRanges, so dollar signs inside code
     are left untouched.
    */

    const displayMathPattern =
        /(?<!\\)\$\$([\s\S]+?)(?<!\\)\$\$/g;


    for (
        const match
        of text.matchAll(
            displayMathPattern
        )
    ) {

        const from =
            match.index;

        const to =
            from +
            match[0].length;


        if (
            insideAnyRange(
                from,
                to,
                protectedRanges
            )
        ) {

            continue;
        }


        const openingLine =
            state.doc.lineAt(
                from
            );

        const closingPosition =
            Math.max(
                from,
                to - 1
            );

        const closingLine =
            state.doc.lineAt(
                closingPosition
            );


        const beforeOpening =
            openingLine.text
                .slice(
                    0,
                    from -
                        openingLine.from
                )
                .trim();

        const afterClosing =
            closingLine.text
                .slice(
                    to -
                        closingLine.from
                )
                .trim();


        const standalone =
            beforeOpening === ""
            &&
            afterClosing === "";


        /*
         A multiline $$ expression must occupy its own
         block. This avoids consuming unrelated text from
         neighbouring lines.
        */

        if (
            match[0].includes("\n")
            &&
            !standalone
        ) {

            continue;
        }


        let replaceFrom =
            from;

        let replaceTo =
            to;


        if (standalone) {

            replaceFrom =
                openingLine.from;

            replaceTo =
                closingLine.to;

            if (
                replaceTo <
                    text.length
                &&
                text[replaceTo] === "\n"
            ) {

                replaceTo += 1;
            }
        }


        protectedRanges.push({
            from:
                replaceFrom,
            to:
                replaceTo
        });


        const active =
            selectionTouches(
                state,
                from,
                to
            );


        if (active) {

            decorations.push(
                Decoration.mark({
                    class:
                        "md-math-source"
                })
                .range(
                    from,
                    to
                )
            );

            continue;
        }


        decorations.push(
            Decoration.replace({

                widget:
                    new MathWidget(
                        match[1],
                        true,
                        from,
                        selectionOverlaps(
                            state,
                            from,
                            to
                        )
                    ),

                block:
                    standalone
            })
            .range(
                replaceFrom,
                replaceTo
            )
        );
    }


    /*
     Inline mathematics:

         The energy is $E = mc^2$.

     $$...$$ ranges have already been protected above and
     therefore cannot accidentally be interpreted as inline
     mathematics.
    */

    const inlineMathPattern =
        /(?<!\\)\$(?!\$)([^$\n]+?)(?<!\\)\$(?!\$)/g;


    for (
        const match
        of text.matchAll(
            inlineMathPattern
        )
    ) {

        const from =
            match.index;

        const to =
            from +
            match[0].length;


        if (
            insideAnyRange(
                from,
                to,
                protectedRanges
            )
        ) {

            continue;
        }


        protectedRanges.push({
            from,
            to
        });


        const active =
            selectionTouches(
                state,
                from,
                to
            );


        if (active) {

            decorations.push(
                Decoration.mark({
                    class:
                        "md-math-source"
                })
                .range(
                    from,
                    to
                )
            );

            continue;
        }


        decorations.push(
            Decoration.replace({

                widget:
                    new MathWidget(
                        match[1],
                        false,
                        from,
                        selectionOverlaps(
                            state,
                            from,
                            to
                        )
                    )
            })
            .range(
                from,
                to
            )
        );
    }


    // Line-level Markdown
    // --------------------------------------------------------

    for (
        const line of lines
    ) {

        if (
            insideAnyRange(
                line.from,
                line.to,
                protectedRanges
            )
        ) {

            continue;
        }


        const active =
            selectionTouches(
                state,
                line.from,
                line.to
            );


        // Headings
        const heading =
            line.text.match(
                /^(#{1,6})[ \t]+(.+)$/
            );

        if (heading) {

            const level =
                heading[1].length;

            const prefixLength =
                heading[1].length +
                (
                    line.text.slice(
                        heading[1].length
                    )
                    .match(/^[ \t]+/)
                    ?.[0]
                    ?.length
                    || 0
                );

            const contentFrom =
                line.from +
                prefixLength;


            decorations.push(
                Decoration.mark({
                    class:
                        `md-heading md-h${level}`
                })
                .range(
                    contentFrom,
                    line.to
                )
            );


            decorations.push(
                Decoration.line({
                    class:
                        `md-heading-line md-h${level}-line`
                })
                .range(
                    line.from
                )
            );


            if (!active) {

                decorations.push(
                    Decoration.replace({})
                        .range(
                            line.from,
                            contentFrom
                        )
                );

            } else {

                decorations.push(
                    Decoration.mark({
                        class:
                            "md-syntax"
                    })
                    .range(
                        line.from,
                        contentFrom
                    )
                );
            }

            continue;
        }


        // Horizontal rule
        if (
            /^\s{0,3}((\*\s*){3,}|(-\s*){3,}|(_\s*){3,})$/
                .test(line.text)
        ) {

            if (!active) {

                let to =
                    line.to +
                    (
                        text[line.to]
                            === "\n"
                        ? 1
                        : 0
                    );

                decorations.push(
                    Decoration.replace({
                        widget:
                            new HorizontalRuleWidget(
                                selectionOverlaps(
                                    state,
                                    line.from,
                                    to
                                )
                            ),
                        block: true
                    })
                    .range(
                        line.from,
                        to
                    )
                );
            }

            continue;
        }


        // Blockquote
        const quote =
            line.text.match(
                /^(\s*(?:>\s*)+)(.*)$/
            );

        if (quote) {

            const prefixLength =
                quote[1].length;

            const level =
                (
                    quote[1]
                        .match(/>/g)
                    || []
                ).length;


            decorations.push(
                Decoration.line({
                    class:
                        "md-blockquote-line",
                    attributes: {
                        style:
                            `--quote-level:${level};`
                    }
                })
                .range(
                    line.from
                )
            );


            if (!active) {

                decorations.push(
                    Decoration.replace({})
                        .range(
                            line.from,
                            line.from +
                                prefixLength
                        )
                );

            } else {

                decorations.push(
                    Decoration.mark({
                        class:
                            "md-syntax"
                    })
                    .range(
                        line.from,
                        line.from +
                            prefixLength
                    )
                );
            }
        }


        // Lists
        const list =
            line.text.match(
                /^([ \t]*)([-+*]|\d+[.)])[ \t]+(.+)$/
            );

        if (list) {

            const indentation =
                list[1]
                    .replace(
                        /\t/g,
                        "    "
                    )
                    .length;

            const level =
                Math.floor(
                    indentation / 2
                );

            const rawMarker =
                list[2];

            const marker =
                /^\d/.test(rawMarker)
                ? rawMarker
                : (
                    level % 3 === 0
                    ? "•"
                    : level % 3 === 1
                    ? "◦"
                    : "▪"
                );


            const contentOffset =
                list[0].length -
                list[3].length;


            decorations.push(
                Decoration.line({
                    class:
                        "md-list-line",
                    attributes: {
                        style:
                            `--list-indent:${8 + level * 26}px;`
                    }
                })
                .range(
                    line.from
                )
            );


            if (!active) {

                decorations.push(
                    Decoration.replace({
                        widget:
                            new ListMarkerWidget(
                                marker,
                                level,
                                selectionOverlaps(
                                    state,
                                    line.from,
                                    line.to
                                )
                            )
                    })
                    .range(
                        line.from,
                        line.from +
                            contentOffset
                    )
                );

            } else {

                decorations.push(
                    Decoration.mark({
                        class:
                            "md-syntax"
                    })
                    .range(
                        line.from,
                        line.from +
                            contentOffset
                    )
                );
            }
        }
    }


    // --------------------------------------------------------
    // Images
    // --------------------------------------------------------

    const imagePattern =
        /!\[([^\]]*)\]\((?:<([^>]+)>|([^\s)]+))(?:\s+["']([^"']*)["'])?\)/g;


    for (
        const match
        of text.matchAll(
            imagePattern
        )
    ) {

        const from =
            match.index;

        const to =
            from +
            match[0].length;


        if (
            insideAnyRange(
                from,
                to,
                protectedRanges
            )
        ) {

            continue;
        }


        const alt =
            match[1] || "";

        const source =
            match[2]
            || match[3]
            || "";

        const title =
            match[4]
            || "";


        const line =
            state.doc.lineAt(
                from
            );


        /*
         If the image is the only thing on the line, render it
         as a normal document image.

         If it occurs inside text, keep it inline.
        */

        const standalone =
            line.text.trim()
            ===
            match[0];


        let replaceFrom =
            from;

        let replaceTo =
            to;


        if (standalone) {

            replaceFrom =
                line.from;

            replaceTo =
                line.to;

            if (
                replaceTo <
                    text.length &&
                text[replaceTo]
                    === "\n"
            ) {

                replaceTo += 1;
            }
        }


        /*
         Protect this Markdown span from link/emphasis parsers
         that run later.
        */

        protectedRanges.push({
            from: replaceFrom,
            to: replaceTo
        });


        const active =
            selectionTouches(
                state,
                from,
                to
            );


        if (active) {

            decorations.push(
                Decoration.mark({
                    class:
                        "md-image-source"
                })
                .range(
                    from,
                    to
                )
            );

            continue;
        }


        const resolvedSource =
            resolveImageURL(
                source
            );


        decorations.push(
            Decoration.replace({

                widget:
                    new ImageWidget(
                        alt,
                        source,
                        resolvedSource,
                        title,
                        from,
                        standalone,
                        selectionOverlaps(
                            state,
                            from,
                            to
                        )
                    ),

                block:
                    standalone
            })
            .range(
                replaceFrom,
                replaceTo
            )
        );
    }


    // --------------------------------------------------------
    // Inline links
    // --------------------------------------------------------

    const linkPattern =
        /\[([^\]]+)]\(([^)\s]+)(?:\s+["'][^"']*["'])?\)/g;

    for (
        const match
        of text.matchAll(linkPattern)
    ) {

        const from =
            match.index;

        const to =
            from +
            match[0].length;


        if (
            insideAnyRange(
                from,
                to,
                protectedRanges
            )
        ) {

            continue;
        }


        if (
            !selectionTouches(
                state,
                from,
                to
            )
        ) {

            decorations.push(
                Decoration.replace({
                    widget:
                        new LinkWidget(
                            match[1],
                            match[2],
                            selectionOverlaps(
                                state,
                                from,
                                to
                            )
                        )
                })
                .range(
                    from,
                    to
                )
            );

        } else {

            decorations.push(
                Decoration.mark({
                    class:
                        "md-link-source"
                })
                .range(
                    from,
                    to
                )
            );
        }
    }


    // --------------------------------------------------------
    // Inline code
    // --------------------------------------------------------

    const inlineCodePattern =
        /`([^`\n]+)`/g;

    for (
        const match
        of text.matchAll(
            inlineCodePattern
        )
    ) {

        const from =
            match.index;

        const to =
            from +
            match[0].length;


        if (
            insideAnyRange(
                from,
                to,
                protectedRanges
            )
        ) {

            continue;
        }


        const contentFrom =
            from + 1;

        const contentTo =
            to - 1;


        decorations.push(
            Decoration.mark({
                class:
                    "md-inline-code"
            })
            .range(
                contentFrom,
                contentTo
            )
        );


        if (
            !selectionTouches(
                state,
                from,
                to
            )
        ) {

            decorations.push(
                Decoration.replace({})
                    .range(
                        from,
                        contentFrom
                    )
            );

            decorations.push(
                Decoration.replace({})
                    .range(
                        contentTo,
                        to
                    )
            );

        } else {

            decorations.push(
                Decoration.mark({
                    class:
                        "md-syntax"
                })
                .range(
                    from,
                    contentFrom
                )
            );

            decorations.push(
                Decoration.mark({
                    class:
                        "md-syntax"
                })
                .range(
                    contentTo,
                    to
                )
            );
        }
    }


    // --------------------------------------------------------
    // Bold
    // --------------------------------------------------------

    const strongPatterns = [
        /\*\*(.+?)\*\*/g,
        /__(.+?)__/g
    ];


    for (
        const pattern
        of strongPatterns
    ) {

        for (
            const match
            of text.matchAll(pattern)
        ) {

            const from =
                match.index;

            const to =
                from +
                match[0].length;


            if (
                insideAnyRange(
                    from,
                    to,
                    protectedRanges
                )
            ) {

                continue;
            }


            const contentFrom =
                from + 2;

            const contentTo =
                to - 2;


            decorations.push(
                Decoration.mark({
                    class:
                        "md-strong"
                })
                .range(
                    contentFrom,
                    contentTo
                )
            );


            if (
                !selectionTouches(
                    state,
                    from,
                    to
                )
            ) {

                decorations.push(
                    Decoration.replace({})
                        .range(
                            from,
                            contentFrom
                        )
                );

                decorations.push(
                    Decoration.replace({})
                        .range(
                            contentTo,
                            to
                        )
                );

            } else {

                decorations.push(
                    Decoration.mark({
                        class:
                            "md-syntax"
                    })
                    .range(
                        from,
                        contentFrom
                    )
                );

                decorations.push(
                    Decoration.mark({
                        class:
                            "md-syntax"
                    })
                    .range(
                        contentTo,
                        to
                    )
                );
            }
        }
    }


    // --------------------------------------------------------
    // Strikethrough
    // --------------------------------------------------------

    const strikePattern =
        /~~(.+?)~~/g;

    for (
        const match
        of text.matchAll(strikePattern)
    ) {

        const from =
            match.index;

        const to =
            from +
            match[0].length;


        if (
            insideAnyRange(
                from,
                to,
                protectedRanges
            )
        ) {

            continue;
        }


        const contentFrom =
            from + 2;

        const contentTo =
            to - 2;


        decorations.push(
            Decoration.mark({
                class:
                    "md-strike"
            })
            .range(
                contentFrom,
                contentTo
            )
        );


        if (
            !selectionTouches(
                state,
                from,
                to
            )
        ) {

            decorations.push(
                Decoration.replace({})
                    .range(
                        from,
                        contentFrom
                    )
            );

            decorations.push(
                Decoration.replace({})
                    .range(
                        contentTo,
                        to
                    )
            );
        }
    }


    // --------------------------------------------------------
    // Italic
    // --------------------------------------------------------

    const italicPatterns = [
        /(?<!\*)\*(?!\*)([^*\n]+?)(?<!\*)\*(?!\*)/g,
        /(?<!_)_(?!_)([^_\n]+?)(?<!_)_(?!_)/g
    ];


    for (
        const pattern
        of italicPatterns
    ) {

        for (
            const match
            of text.matchAll(pattern)
        ) {

            const from =
                match.index;

            const to =
                from +
                match[0].length;


            if (
                insideAnyRange(
                    from,
                    to,
                    protectedRanges
                )
            ) {

                continue;
            }


            const contentFrom =
                from + 1;

            const contentTo =
                to - 1;


            decorations.push(
                Decoration.mark({
                    class:
                        "md-em"
                })
                .range(
                    contentFrom,
                    contentTo
                )
            );


            if (
                !selectionTouches(
                    state,
                    from,
                    to
                )
            ) {

                decorations.push(
                    Decoration.replace({})
                        .range(
                            from,
                            contentFrom
                        )
                );

                decorations.push(
                    Decoration.replace({})
                        .range(
                            contentTo,
                            to
                    )
                );
            }
        }
    }


    if (
        text.length > 0 &&
        !window.__mdonnaDecorationCountLogged
    ) {

        window.__mdonnaDecorationCountLogged = true;

        sendToNative({
            type: "log",
            message:
                "LIVE PREVIEW DECORATIONS = "
                + decorations.length
        });
    }

    /*
     Visible selection layer.

     A large part of MDonna's live preview is rendered with
     decorations and widgets, so relying only on CodeMirror's
     native selection rectangles is not enough.

     Add an explicit mark over every non-empty selected source
     range. Widgets receive their own selected state above.
    */

    for (
        const range
        of state.selection.ranges
    ) {

        if (range.empty) {
            continue;
        }

        if (range.to > range.from) {

            decorations.push(
                Decoration.mark({
                    class:
                        "md-visible-selection"
                })
                .range(
                    range.from,
                    range.to
                )
            );
        }
    }


    return Decoration.set(
        decorations,
        true
    );
}


// ============================================================
// Live Preview StateField
// ============================================================

function safeBuildDecorations(
    state,
    context
) {

    try {

        return buildDecorations(
            state
        );

    } catch (error) {

        sendToNative({
            type: "log",
            message:
                "LIVE PREVIEW " +
                context +
                " ERROR: " +
                String(
                    error?.stack
                    || error
                )
        });

        return Decoration.none;
    }
}


const livePreviewField =
    StateField.define({

        create(state) {

            return safeBuildDecorations(
                state,
                "CREATE"
            );
        },


        update(
            decorations,
            transaction
        ) {

            // Rebuild from the resulting editor state.
            //
            // This intentionally happens for every transaction
            // for now. Correctness comes first; later we can
            // optimise large-document performance.

            return safeBuildDecorations(
                transaction.state,
                "UPDATE"
            );
        },


        provide:
            field =>
                EditorView.decorations.from(
                    field
                )
    });


// ============================================================
// Native document synchronisation
// ============================================================

const updateListener =
    EditorView.updateListener.of(
        update => {

            const selection =
                update.state.selection.main;

            const entireDocumentSelected =
                update.state.doc.length > 0
                &&
                selection.from === 0
                &&
                selection.to ===
                    update.state.doc.length;


            update.view.dom.classList.toggle(
                "md-entire-document-selected",
                entireDocumentSelected
            );


            if (
                !update.docChanged
            ) {

                return;
            }


            sendMarkdownToNative(
                update.state.doc.toString()
            );
        }
    );


// ============================================================
// Editor state
// ============================================================

const state =
    EditorState.create({

        doc: "",

        extensions: [
                imageTransferHandlers,

                mdonnaSyntaxHighlightExtension,


            history(),

            drawSelection(),

            markdown({
                    codeLanguages:
                        mdonnaCodeLanguages,

                base:
                    markdownLanguage,
                extensions:
                    [GFM]
            }),

            keymap.of([
                {
                    key: "Mod-a",
                    run: selectAll
                },

                indentWithTab,

                ...defaultKeymap,
                ...historyKeymap,
                ...searchKeymap
            ]),

            livePreviewField,

            updateListener,

            EditorView.lineWrapping
        ]
    });


const view =
    new EditorView({

        state,

        parent:
            document.getElementById(
                "editor"
            )
    });


// ============================================================
// API used by Swift
// ============================================================

window.MDonna = {

    setMarkdown(markdownText) {

        const incoming =
            markdownText ?? "";

        const current =
            view.state.doc.toString();

        if (
            incoming === current
        ) {

            return;
        }


        applyingNativeUpdate =
            true;

        try {

            view.dispatch({

                changes: {

                    from: 0,

                    to:
                        view.state.doc.length,

                    insert:
                        incoming
                }
            });

            sendToNative({
                type: "log",
                message:
                    "SET MARKDOWN COMPLETE; state length = "
                    + view.state.doc.length
            });

            setTimeout(
                () => {

                    const stats = {
                        headings:
                            document.querySelectorAll(
                                ".md-heading"
                            ).length,

                        strong:
                            document.querySelectorAll(
                                ".md-strong"
                            ).length,

                        inlineCode:
                            document.querySelectorAll(
                                ".md-inline-code"
                            ).length,

                        codeBlocks:
                            document.querySelectorAll(
                                ".md-code-block"
                            ).length,

                        tables:
                            document.querySelectorAll(
                                ".md-table"
                            ).length,

                        listMarkers:
                            document.querySelectorAll(
                                ".md-list-marker"
                            ).length
                    };

                    sendToNative({
                        type: "log",
                        message:
                            "LIVE PREVIEW DOM = "
                            + JSON.stringify(stats)
                    });

                },
                250
            );

        } finally {

            applyingNativeUpdate =
                false;
        }
    },


    completeImageImport(
        requestID,
        relativePath,
        altText,
        requestedPosition
    ) {

        const resolve =
            pendingImageImports.get(
                requestID
            );


        pendingImageImports.delete(
            requestID
        );


        const safeAlt =
            String(
                altText || "Image"
            )
            .replace(
                /[\[\]\n\r]/g,
                " "
            )
            .trim();


        const markdown =
            `![${safeAlt}](<${relativePath}>)`;


        const position =
            Math.max(
                0,
                Math.min(
                    Number(
                        requestedPosition
                    ) || 0,
                    view.state.doc.length
                )
            );


        view.dispatch({

            changes: {

                from:
                    position,

                to:
                    position,

                insert:
                    markdown
            },

            selection: {

                anchor:
                    position +
                    markdown.length
            },

            scrollIntoView:
                true
        });


        view.focus();


        if (resolve) {

            resolve({

                position:
                    position +
                    markdown.length
            });
        }
    },


    failImageImport(
        requestID,
        message
    ) {

        const resolve =
            pendingImageImports.get(
                requestID
            );


        pendingImageImports.delete(
            requestID
        );


        console.error(
            "MDonna image import:",
            message
        );


        if (resolve) {

            resolve(null);
        }
    },


    setDocumentContext(
        baseURL
    ) {

        documentBaseURL =
            baseURL || null;


        /*
         No text has changed, but image URLs may now resolve
         differently — for example immediately after Save As.
         Dispatch an empty transaction so the StateField
         rebuilds its decorations.
        */

        view.dispatch({});
    },


    getMarkdown() {

        return view.state.doc.toString();
    },


    focus() {

        view.focus();
    }
};


sendToNative({
    type: "log",
    message:
        "EDITOR.JS LOADED"
});

sendToNative({
    type: "ready"
});
