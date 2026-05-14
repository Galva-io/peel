import Foundation

/// Renders a decoded `JSONValue` tree to a self-contained HTML document.
///
/// Why HTML?
///   • The native SwiftUI tree builds one View per node. For a
///     `getTransactionHistory` payload with 1k transactions that means ~50k
///     nested views, which has to happen on the main thread and stutters.
///   • WebKit virtualises long documents and uses native `<details>` for
///     collapsibles, so we get smooth scrolling and find-in-page for free.
///   • The HTML generation itself is pure work — fast, off-main-thread.
///
/// The renderer is intentionally string-based with no JS-side templating: a
/// single recursive walk producing a string. Search and click-to-copy are
/// implemented in a tiny inline script.
public struct JSONHTMLRenderer: Sendable {
    public struct Options: Sendable {
        public var initiallyOpenDepth: Int
        public var showSemanticHints: Bool

        public static let `default` = Options(initiallyOpenDepth: 4, showSemanticHints: true)

        public init(initiallyOpenDepth: Int = 4, showSemanticHints: Bool = true) {
            self.initiallyOpenDepth = initiallyOpenDepth
            self.showSemanticHints = showSemanticHints
        }
    }

    public let options: Options

    public init(options: Options = .default) {
        self.options = options
    }

    public func render(_ root: JSONValue) -> String {
        var body = ""
        body.reserveCapacity(8_192)
        renderValue(root, name: nil, depth: 0, into: &body)
        return Self.shell.replacingOccurrences(of: "__TREE__", with: body)
    }

    // MARK: - Recursive walk

    private func renderValue(_ value: JSONValue, name: String?, depth: Int, into out: inout String) {
        switch value {
        case .null:
            renderLeaf(name: name, html: "<span class=\"val null\">null</span>", into: &out)
        case let .bool(b):
            renderLeaf(name: name, html: "<span class=\"val bool\">\(b ? "true" : "false")</span>", into: &out)
        case let .number(n):
            renderLeaf(name: name, html: "<span class=\"val num\">\(Self.escape(n.literal))</span>", into: &out)
        case let .string(s):
            renderLeaf(name: name, html: "<span class=\"val str\">\(Self.escapeQuotedString(s))</span>", into: &out)
        case let .array(items):
            renderArray(name: name, items: items, depth: depth, into: &out)
        case let .object(pairs):
            renderObject(name: name, pairs: pairs, depth: depth, into: &out)
        }
    }

    private func renderLeaf(name: String?, html: String, into out: inout String) {
        out.append("<div class=\"row\">")
        if let name {
            out.append("<span class=\"key\">\(Self.escape(name))</span><span class=\"colon\">:</span> ")
        }
        out.append(html)
        if let name, options.showSemanticHints, let hint = SemanticFieldDescriptions.label(for: name) {
            out.append(" <span class=\"hint\">\(Self.escape(hint))</span>")
        }
        out.append("</div>")
    }

    private func renderArray(name: String?, items: [JSONValue], depth: Int, into out: inout String) {
        if items.isEmpty {
            renderLeaf(name: name, html: "<span class=\"val empty\">[ ]</span>", into: &out)
            return
        }
        let openAttr = depth < options.initiallyOpenDepth ? " open" : ""
        out.append("<details class=\"arr\"\(openAttr)>")
        out.append("<summary>")
        if let name {
            out.append("<span class=\"key\">\(Self.escape(name))</span><span class=\"colon\">:</span> ")
        }
        out.append("<span class=\"meta\">[\(items.count) item\(items.count == 1 ? "" : "s")]</span>")
        out.append("</summary>")
        out.append("<div class=\"children\">")
        for (index, item) in items.enumerated() {
            renderValue(item, name: "\(index)", depth: depth + 1, into: &out)
        }
        out.append("</div>")
        out.append("</details>")
    }

    private func renderObject(name: String?, pairs: [JSONValue.Pair], depth: Int, into out: inout String) {
        let isJWS = pairs.contains(where: { $0.key == "__peel_jws" })
        if pairs.isEmpty {
            renderLeaf(name: name, html: "<span class=\"val empty\">{ }</span>", into: &out)
            return
        }
        let openAttr = depth < options.initiallyOpenDepth ? " open" : ""
        out.append("<details class=\"obj\(isJWS ? " jws" : "")\"\(openAttr)>")
        out.append("<summary>")
        if let name {
            out.append("<span class=\"key\">\(Self.escape(name))</span><span class=\"colon\">:</span> ")
        }
        out.append("<span class=\"meta\">{\(pairs.count) field\(pairs.count == 1 ? "" : "s")}</span>")
        if isJWS { out.append("<span class=\"badge\">decoded JWS</span>") }
        out.append("</summary>")
        out.append("<div class=\"children\">")
        for pair in pairs {
            // The JWS envelope sentinel is internal — don't bother showing it.
            if pair.key == "__peel_jws" { continue }
            renderValue(pair.value, name: pair.key, depth: depth + 1, into: &out)
        }
        out.append("</div>")
        out.append("</details>")
    }

    // MARK: - HTML escaping

    private static func escape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for scalar in s.unicodeScalars {
            switch scalar {
            case "&": out.append("&amp;")
            case "<": out.append("&lt;")
            case ">": out.append("&gt;")
            case "\"": out.append("&quot;")
            case "'": out.append("&#39;")
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    private static func escapeQuotedString(_ s: String) -> String {
        "\"" + escape(s) + "\""
    }

    // MARK: - HTML shell

    /// The page mimics macOS native styling: system monospaced font, system
    /// label colors via `-apple-system` CSS keywords, and a find bar that's
    /// hidden until ⌘F summons it (matching `NSTextFinder`'s incremental
    /// reveal behavior). No decorative purple — the JWS envelope is signaled
    /// by a thin leading border, same restraint Xcode's source list uses.
    static let shell: String = #"""
    <!doctype html>
    <html>
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width">
    <style>
      :root {
        color-scheme: light dark;
        --bg: transparent;
        --fg: -apple-system-label;
        --muted: -apple-system-secondary-label;
        --tertiary: -apple-system-tertiary-label;
        --string: #1f7a3a;
        --number: #1652cf;
        --bool: #b1530f;
        --separator: rgba(120, 120, 128, 0.22);
        --row-hover: rgba(120, 120, 128, 0.08);
        --highlight: color-mix(in srgb, -apple-system-yellow 35%, transparent);
      }
      @media (prefers-color-scheme: dark) {
        :root {
          --string: #6acb6a;
          --number: #6ea8fe;
          --bool: #ffa552;
          --row-hover: rgba(255, 255, 255, 0.04);
        }
      }
      html, body {
        background: var(--bg);
        color: var(--fg);
        margin: 0; padding: 0;
        /* `ui-monospace` resolves to SF Mono on macOS — the same face Xcode,
           Console, and Terminal use as their default. */
        font: 12px/1.45 ui-monospace, "SF Mono", Menlo, monospace;
        font-feature-settings: "tnum" 1;
        -webkit-font-smoothing: antialiased;
      }
      body { padding: 8px 14px 24px; }
      #find {
        position: sticky; top: 0;
        background: var(--bg);
        backdrop-filter: blur(8px);
        margin: 0 -14px;
        padding: 6px 14px;
        border-bottom: 1px solid var(--separator);
        display: none;
        z-index: 10;
      }
      #find.visible { display: flex; align-items: center; gap: 8px; }
      #q {
        flex: 1;
        padding: 4px 8px;
        font: inherit;
        background: color-mix(in srgb, currentColor 8%, transparent);
        color: var(--fg);
        border: 1px solid transparent;
        border-radius: 5px;
        outline: none;
      }
      #q:focus { border-color: color-mix(in srgb, -apple-system-blue 60%, transparent); }
      #count { color: var(--muted); font-size: 11px; min-width: 56px; text-align: right; }
      .row { padding: 1px 0 1px 14px; }
      .row:hover { background: var(--row-hover); }
      details { padding-left: 14px; }
      details > summary {
        list-style: none; cursor: pointer; user-select: none;
        padding: 1px 0 1px 14px;
        margin-left: -14px;
        position: relative;
      }
      details > summary::-webkit-details-marker { display: none; }
      details > summary::before {
        content: "▸";
        position: absolute; left: 0;
        color: var(--tertiary);
        font-size: 10px; line-height: 1.6;
        transition: transform 0.08s ease-out;
      }
      details[open] > summary::before { transform: rotate(90deg); }
      details > summary:hover { background: var(--row-hover); }
      .children { padding-left: 14px; }
      .key { color: var(--fg); }
      .colon { color: var(--tertiary); margin-right: 2px; }
      .val.str { color: var(--string); }
      .val.num { color: var(--number); }
      .val.bool { color: var(--bool); }
      .val.null { color: var(--tertiary); font-style: italic; }
      .val.empty { color: var(--tertiary); }
      .meta { color: var(--muted); margin-left: 4px; }
      .hint { color: var(--tertiary); font-style: italic; margin-left: 6px; }
      /* JWS envelope: subtle left border instead of a colored badge. */
      details.jws { border-left: 2px solid var(--separator); padding-left: 12px; }
      .badge {
        color: var(--muted);
        font-size: 10px; font-weight: 600;
        letter-spacing: 0.02em; text-transform: uppercase;
        margin-left: 6px;
      }
      .match { background: var(--highlight); border-radius: 2px; }
    </style>
    </head>
    <body>
      <div id="find">
        <input id="q" type="search" placeholder="Find" autocomplete="off" spellcheck="false">
        <span id="count"></span>
      </div>
      <div id="tree">__TREE__</div>
      <script>
        (function () {
          const find = document.getElementById('find');
          const q = document.getElementById('q');
          const count = document.getElementById('count');
          const tree = document.getElementById('tree');
          let timer = null;
          let matches = [];
          let cursor = 0;

          function clearMatches() {
            matches.forEach(el => el.classList.remove('match'));
            matches = [];
            cursor = 0;
            count.textContent = '';
          }
          function applySearch(term) {
            clearMatches();
            if (!term) return;
            const lower = term.toLowerCase();
            tree.querySelectorAll('.key, .val, .meta').forEach(el => {
              if (el.textContent.toLowerCase().includes(lower)) matches.push(el);
            });
            matches.forEach(el => {
              el.classList.add('match');
              let p = el.parentElement;
              while (p && p !== tree) {
                if (p.tagName === 'DETAILS') p.open = true;
                p = p.parentElement;
              }
            });
            count.textContent = matches.length ? '1 of ' + matches.length : 'No matches';
            if (matches[0]) matches[0].scrollIntoView({ block: 'center', behavior: 'instant' });
          }
          function step(delta) {
            if (matches.length === 0) return;
            cursor = (cursor + delta + matches.length) % matches.length;
            matches[cursor].scrollIntoView({ block: 'center', behavior: 'instant' });
            count.textContent = (cursor + 1) + ' of ' + matches.length;
          }

          q.addEventListener('input', () => {
            clearTimeout(timer);
            timer = setTimeout(() => applySearch(q.value.trim()), 80);
          });
          q.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') { e.preventDefault(); step(e.shiftKey ? -1 : 1); }
            if (e.key === 'Escape') { hideFind(); }
          });

          function showFind() {
            find.classList.add('visible');
            q.focus(); q.select();
          }
          function hideFind() {
            find.classList.remove('visible');
            clearMatches();
            q.value = '';
          }

          window.addEventListener('keydown', (e) => {
            if ((e.metaKey || e.ctrlKey) && e.key === 'f') {
              e.preventDefault();
              showFind();
            } else if (e.key === 'Escape' && find.classList.contains('visible')) {
              hideFind();
            }
          });

          document.addEventListener('click', (e) => {
            if (e.altKey && (e.target.classList.contains('val') || e.target.classList.contains('key'))) {
              e.preventDefault();
              navigator.clipboard?.writeText(e.target.textContent || '');
            }
          });
        })();
      </script>
    </body>
    </html>
    """#
}
