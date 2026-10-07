// Ctrl+W on a PINNED tab unloads (discards) it instead of doing nothing.
// Non-pinned tabs keep the stock behavior (Ctrl+W still closes them).
//
// Where to put it:  <browser install dir>/config.js     e.g. D:\Program Files\Waterfox\config.js
// Companion file:   <browser install dir>/defaults/pref/autoconfig.js
//
// NOTE: AutoConfig skips the first line of this file, so line 1 must stay a comment.
//
// Verified on: Waterfox 153.4.0 / Windows / vertical tabs (sidebar.verticalTabs=true)
//   real keystroke -> pinned tab discarded=true, linkedPanel=false, still pinned in the strip
(function () {
  // In the AutoConfig scope Cc / Ci / Components / Services are already global.
  // There is no setTimeout, and ChromeUtils.importESModule("resource://...") fails here,
  // so use the ambient Services object only.
  const Services = globalThis.Services;
  if (!Services) {
    return;
  }

  const isMac = Services.appinfo.OS === "Darwin";

  function onKeyDown(event) {
    if (event.__pinnedCtrlWHandled) {
      return; // the same keypress can be delivered once per event group
    }
    // Cmd+W on macOS, Ctrl+W everywhere else
    const accel = isMac ? event.metaKey && !event.ctrlKey : event.ctrlKey;
    if (!accel || event.shiftKey || event.altKey) {
      return;
    }
    if (String(event.key).toLowerCase() !== "w") {
      return;
    }

    const win = event.currentTarget;
    const gBrowser = win.gBrowser;
    if (!gBrowser) {
      return;
    }

    const tab = gBrowser.selectedTab;
    if (!tab || !tab.pinned || gBrowser.multiSelectedTabsCount) {
      return; // not a pinned tab: do not interfere at all
    }
    if (!tab.linkedPanel || !tab.linkedBrowser?.isRemoteBrowser) {
      return; // already unloaded, or an internal page that cannot be discarded
    }

    event.__pinnedCtrlWHandled = true;
    event.preventDefault();

    // Same code path as the built-in "Unload Tab" context-menu item:
    // runs beforeunload handlers, moves the selection to another tab if needed,
    // then discards the browser and marks the tab as explicitly unloaded.
    gBrowser.explicitUnloadTabs([tab]).catch(() => {});
  }

  // Attach one listener per browser window.
  // mozSystemGroup is required: Ctrl+W is a reserved shortcut and is only delivered
  // to the system event group. The plain listener is a fallback (idempotent via the flag).
  Services.obs.addObserver(
    {
      observe(subject, topic) {
        if (topic !== "chrome-document-global-created") {
          return;
        }
        let href = "";
        try {
          href = subject.location.href;
        } catch (e) {
          return;
        }
        if (href !== "chrome://browser/content/browser.xhtml") {
          return;
        }
        subject.addEventListener("keydown", onKeyDown, {
          capture: true,
          mozSystemGroup: true,
        });
        subject.addEventListener("keydown", onKeyDown, { capture: true });
      },
    },
    "chrome-document-global-created"
  );
})();
