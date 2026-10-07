# Ctrl+W unloads a pinned tab (Waterfox / Firefox AutoConfig patch)

In Waterfox — and in Firefox — pressing <kbd>Ctrl</kbd>+<kbd>W</kbd> while a **pinned** tab is
selected does *nothing*: the shortcut is hard-coded to jump to the first unpinned tab instead of
closing or unloading the pinned one, and pinned tabs have no close button. The only built-in way to
free their memory is right-click → **Unload Tab**.

This patch makes <kbd>Ctrl</kbd>+<kbd>W</kbd> on a pinned tab **unload (discard)** it:

* the tab stays in the tab strip and stays pinned (it just greys out),
* its content process is released — memory is actually freed,
* clicking the tab reloads the page,
* every other tab keeps the stock behavior (`Ctrl+W` really closes non-pinned tabs).

## How it works

1. `defaults/pref/autoconfig.js` in the browser's **install** directory enables the built-in
   [AutoConfig](https://support.mozilla.org/kb/customizing-firefox-using-autoconfig) hook.
2. `config.js` (install directory root) observes `chrome-document-global-created` and attaches a
   `keydown` listener — `capture: true` **and** `mozSystemGroup: true`, which is required because
   `Ctrl+W` is a reserved shortcut delivered in the system event group — to every browser window.
3. When the currently selected tab is pinned, the handler calls
   `gBrowser.explicitUnloadTabs([tab])`: the exact code path the built-in *Unload Tab* menu item
   uses. It runs `beforeunload` handlers, moves the selection to another tab if needed, then
   discards the browser and sets the `discarded` state (the greyed-out look).

No tabs, shortcuts or pages other than "Ctrl+W on a pinned tab" are affected.

## Requirements

* Waterfox (tested on **153.4.0**) or Firefox with the pinned-tab unload feature in the tab context
  menu (Firefox 143+ / the Firefox base Waterfox 153 ships).
* Write access to the browser's **install** directory (admin / sudo).
* Windows: use `install.ps1`. Linux/macOS: copy two files by hand (below).

## Install — Windows

```powershell
git clone https://github.com/MinamiHashiRun0/ctrl-w-unload-pinned-tab.git
cd ctrl-w-unload-pinned-tab
powershell -ExecutionPolicy Bypass -File .\install.ps1
# other install location:
#   ... -File .\install.ps1 -AppDir 'C:\Program Files\Waterfox'
```

Then **fully quit** the browser (check Task Manager for a leftover `waterfox.exe`) and start it again.

## Install — Linux / macOS (manual)

| file | destination |
|---|---|
| `config.js` | `<install dir>/config.js` |
| `autoconfig.js` | `<install dir>/defaults/pref/autoconfig.js` |

Typical install dirs: `/usr/lib/waterfox`, `/opt/waterfox`, `/Applications/Waterfox.app/Contents/Resources`
(for `.app` bundles put both files inside `Resources`). AutoConfig is only read from the install
directory — a `defaults/pref` file inside your profile does nothing.

## Verify

* Pin a tab, press <kbd>Ctrl</kbd>+<kbd>W</kbd>: the tab greys out, stays pinned, and appears in
  `about:processes` as no longer taking a content process.
* `about:config` → `general.config.filename` should read `config.js`.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Rollback
```

or just delete `<install dir>/config.js` and `<install dir>/defaults/pref/autoconfig.js`.

`install.ps1` copies any pre-existing `config.js` / `autoconfig.js` into `backup-<timestamp>/`
before touching them.

## Verified

Waterfox 153.4.0, Windows, **vertical tabs enabled** (`sidebar.verticalTabs = true`), a real keyboard
<kbd>Ctrl</kbd>+<kbd>W</kbd> sent to a window whose selected tab was pinned:

```
test:             verticalMode=true tabs=3
after-pin:        isPinned=true isSelected=true
case-before:      isSelected=true pinned=true hasLinkedPanel=true isRemote=true ready=true
[handler]         Ctrl+W on pinned tab -> explicitUnloadTabs
case-after:       discarded=true hasLinkedPanel=false stillInStrip=true stillPinned=true
RESULT:           pinnedTabUnloadedByRealKey=true
```

Gotchas discovered while building this (they bite anyone writing an AutoConfig script):

* In the AutoConfig scope there is **no `setTimeout`**, and
  `ChromeUtils.importESModule("resource://gre/modules/Services.sys.mjs")` **fails**.
  `Cc`, `Ci`, `Components`, `Cu`, `Services`, `ChromeUtils` and `Promise` *are* available.
* `Ctrl+W` is a reserved shortcut: a plain `window.addEventListener("keydown", …)` may never see it.
  Register with `mozSystemGroup: true` (that is how Firefox's own reserved-shortcut handlers do it).
* AutoConfig skips the **first line** of `config.js`; keep a comment there.

## Caveats

* `general.config.sandbox_enabled = false` is required (the script needs `Services` / `Cc`). This
  disables the AutoConfig sandbox for this one file — it is a chrome-privileged script either way,
  so keep it reviewable and don't paste third-party code into it.
* Browser updates normally leave these files alone (they are not part of the update manifest). If the
  patch stops working after an upgrade, re-copy the two files.
* macOS support (`Cmd+W`) is included but **has not been tested** — the verification above is
  Windows-only.
* This is not a WebExtension: it cannot be installed from addons.mozilla.org and it must live in the
  install directory.

## Files

| file | purpose |
|---|---|
| `config.js` | the patch itself (chrome-privileged AutoConfig script) |
| `autoconfig.js` | three `pref(...)` lines that enable AutoConfig and point it at `config.js` |
| `install.ps1` | Windows installer with backup + `-Rollback` |

## 中文摘要

Waterfox/Firefox 里 `Ctrl+W` 打在**固定标签页**上是硬编码的「不关闭、跳到第一个非固定标签页」，
没有任何 about:config 开关，也没有扩展能抢到这个保留快捷键。本补丁通过 AutoConfig 往浏览器注入
一小段脚本：当前标签页是固定标签页时，`Ctrl+W` 改为调用 `gBrowser.explicitUnloadTabs([tab])`
（与右键菜单「卸载标签页」完全同一条路径）——标签页保持固定并留在标签栏，内容进程被释放。
非固定标签页的 `Ctrl+W` 行为不变。已在 Waterfox 153.4.0 + 垂直标签页 + 真实键盘按键下实测通过。

## License

MIT — see [LICENSE](LICENSE).
