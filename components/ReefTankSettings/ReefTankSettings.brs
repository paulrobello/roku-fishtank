' Layout is authored at 1920x1080 and the panel Group is scaled to the UI resolution.
sub init()
    PANEL_W = 1100
    PANEL_H = 760
    m.rowH = 58
    m.rowsY = 200
    dr = m.top.currentDesignResolution
    s = dr.width / 1920.0

    backdrop = m.top.findNode("backdrop")
    backdrop.width = 2546 * s
    backdrop.height = 1080 * s
    backdrop.translation = [-313 * s, 0]
    shade = m.top.findNode("dim")
    shade.width = dr.width
    shade.height = dr.height

    panel = m.top.findNode("panel")
    panel.scale = [s, s]
    panel.translation = [(dr.width - PANEL_W * s) / 2, (dr.height - PANEL_H * s) / 2]
    m.top.findNode("panelBg").width = PANEL_W
    m.top.findNode("panelBg").height = PANEL_H
    edge = m.top.findNode("panelEdge")
    edge.width = PANEL_W
    edge.height = 4
    edge.translation = [0, 0]

    titleFont = "font:LargeBoldSystemFont"
    bodyFont = "font:MediumBoldSystemFont"
    smallFont = "font:SmallestSystemFont"
    m.top.findNode("subtitle").text = tr("Screensaver settings")
    m.top.findNode("hint").text = tr("OK changes a value. Up / down moves. Back saves and exits.")
    settingsUiPlace(m.top.findNode("title"), titleFont, 60, 36, PANEL_W - 120, 90)
    settingsUiPlace(m.top.findNode("subtitle"), smallFont, 60, 110, PANEL_W - 120, 64)
    settingsUiPlace(m.top.findNode("hint"), smallFont, 60, PANEL_H - 82, PANEL_W - 120, 64)

    ' Keep Solar location at index 3 even when new persisted preferences are added.
    m.keys = ["nightMode", "density", "drift", "solarLocation", "digitalClock", "clockFormat", "changelog", "launchReport"]
    m.titles = { nightMode: tr("Night mode"), density: tr("Fish density"), drift: tr("Camera drift"), digitalClock: tr("Background clock"), clockFormat: tr("Clock format") }
    m.shown = {
        nightMode: { auto: tr("Auto"), day: tr("Always day"), night: tr("Always night") }
        density: { calm: tr("Calm"), normal: tr("Normal"), busy: tr("Busy") }
        drift: { on: tr("On"), off: tr("Off") }
        digitalClock: { on: tr("On"), off: tr("Off") }
        clockFormat: { device: tr("Device setting"), "12h": tr("12-hour"), "24h": tr("24-hour") }
    }
    m.store = settingsRegistryStore()
    m.values = settingsLoad(m.store)
    m.location = settingsLocationLoad(m.store)

    ' Native list navigation handles Up/Down and OK in the separate settings context.
    ' No custom key handler is included in the screensaver package.
    m.options = m.top.findNode("options")
    m.options.translation = [60, m.rowsY]
    m.options.itemSize = [PANEL_W - 120, m.rowH]
    m.options.itemSpacing = [0, 0]
    m.options.numRows = m.keys.count()
    m.options.font = bodyFont
    m.options.focusedFont = bodyFont
    content = createObject("roSGNode", "ContentNode")
    for each key in m.keys
        content.createChild("ContentNode")
    end for
    m.options.content = content
    settingsUiRefresh()
    m.options.observeField("itemSelected", "settingsUiSelected")
    m.options.setFocus(true)
    m.places = m.top.findNode("places")
    m.places.observeField("itemSelected", "settingsUiPlaceSelected")
end sub

sub settingsUiPlace(label as object, font as string, x as integer, y as integer, w as integer, h as integer)
    label.font = font
    label.translation = [x, y]
    label.width = w
    label.height = h
    label.vertAlign = "center"
end sub

' Update native list labels without replacing its content or moving focus.
sub settingsUiRefresh()
    for i = 0 to m.keys.count() - 1
        key = m.keys[i]
        if key = "solarLocation" then
            m.options.content.getChild(i).title = tr("Solar location: %1").replace("%1", settingsLocationLabel(m.location))
        else if key = "changelog" then
            m.options.content.getChild(i).title = tr("Changelog")
        else if key = "launchReport" then
            m.options.content.getChild(i).title = tr("Launch report")
        else
            m.options.content.getChild(i).title = tr("%1: %2").replace("%1", m.titles[key]).replace("%2", m.shown[key][m.values[key]])
        end if
    end for
end sub

sub settingsUiSelected()
    row = m.options.itemSelected
    if row < 0 or row >= m.keys.count() then return
    key = m.keys[row]
    if key = "solarLocation" then
        settingsUiLocation()
        return
    end if
    if key = "launchReport" then
        settingsUiLaunchReport()
        return
    end if
    if key = "changelog" then
        m.changelogEntries = ParseJson(ReadAsciiFile("pkg:/config/changelog.json"))
        if m.changelogEntries = invalid then return
        if m.changelogEntries.count() = 0 then return
        m.changelogIndex = 0
        settingsUiChangelog()
        return
    end if
    m.values[key] = settingsStep(key, m.values[key], 1)
    settingsSave(m.store, m.values)
    settingsUiRefresh()
end sub

sub settingsUiLocation()
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = tr("Solar location")
    dialog.message = tr("Choose a ZIP, nearby city, or coordinates. Keep your Roku time zone correct. Location stays on this device.")
    dialog.buttons = [tr("US ZIP code"), tr("Country / city"), tr("Custom coordinates"), tr("Cancel")]
    dialog.observeField("buttonSelected", "settingsUiLocationSelected")
    dialog.observeField("wasClosed", "settingsUiDialogClosed")
    m.top.dialog = dialog
end sub

sub settingsUiLocationSelected(event as object)
    choice = event.getData()
    dialog = m.top.dialog
    dialog.close = true
    if choice = 0 then
        keyboard = CreateObject("roSGNode", "StandardKeyboardDialog")
        keyboard.title = tr("US ZIP code")
        keyboard.message = [tr("Enter five digits, then select Save ZIP below the keyboard.")]
        keyboard.keyboardDomain = "numeric"
        keyboard.buttons = [tr("Save ZIP"), tr("Use remote digits"), tr("Cancel")]
        keyboard.observeField("buttonSelected", "settingsUiZipKeyboardSelected")
        keyboard.observeField("wasClosed", "settingsUiDialogClosed")
        m.top.dialog = keyboard
    else if choice = 1 then
        settingsUiCountries()
    else if choice = 2 then
        keyboard = CreateObject("roSGNode", "StandardKeyboardDialog")
        keyboard.title = tr("Latitude, longitude")
        keyboard.message = [tr("Example: 35.2271,-80.8431. Select Save below the keyboard.")]
        keyboard.text = m.location.text
        keyboard.buttons = [tr("Save"), tr("Cancel")]
        keyboard.observeField("buttonSelected", "settingsUiCoordinatesSelected")
        keyboard.observeField("wasClosed", "settingsUiDialogClosed")
        m.top.dialog = keyboard
    end if
end sub

sub settingsUiZipKeyboardSelected(event as object)
    dialog = m.top.dialog
    choice = event.getData()
    if choice = 0 then
        loc = locationZipRead(dialog.text.trim())
        if loc = invalid then
            dialog.title = tr("ZIP not found")
            dialog.message = [tr("Use five digits including leading zeros. Some ZIPs need city / coordinates instead.")]
            return
        end if
        settingsLocationSave(m.store, loc.text)
        m.location = settingsLocationLoad(m.store)
        settingsUiRefresh()
    end if
    dialog.close = true
    if choice = 1 then
        m.zipDigits = [0, 0, 0, 0, 0]
        settingsUiZipDigits(0)
    end if
end sub

sub settingsUiZipDigits(focus as integer)
    m.placeMode = "zip"
    names = []
    for i = 0 to 4
        names.push(tr("Digit %1: %2").replace("%1", (i + 1).toStr()).replace("%2", m.zipDigits[i].toStr()))
    end for
    names.push(tr("Save ZIP: %1").replace("%1", locationZipDigits(m.zipDigits)))
    names.push(tr("Cancel"))
    settingsUiShowPlaces(names, tr("ZIP %1 - OK cycles each digit 0-9").replace("%1", locationZipDigits(m.zipDigits)))
    m.places.jumpToItem = focus
    m.top.findNode("hint").text = tr("Up / down selects a digit. OK changes it. Then choose Save ZIP.")
end sub

sub settingsUiZipSelected(selected as integer)
    if selected < 5 then
        m.zipDigits[selected] = (m.zipDigits[selected] + 1) mod 10
        settingsUiZipDigits(selected)
    else if selected = 5 then
        loc = locationZipRead(locationZipDigits(m.zipDigits))
        if loc = invalid then
            m.top.findNode("subtitle").text = tr("ZIP not found. Change digits, or Cancel and use city / coordinates.")
            return
        end if
        settingsLocationSave(m.store, loc.text)
        settingsUiEndPlaces()
    else if selected = 6 then
        settingsUiEndPlaces()
    end if
end sub

sub settingsUiCountries()
    m.countryRows = ParseJson(ReadAsciiFile("pkg:/config/location/countries.json"))
    if m.countryRows = invalid then return
    m.placeMode = "country"
    names = [tr("Cancel")]
    for each row in m.countryRows
        names.push(settingsUiCountryName(row[0]))
    end for
    settingsUiShowPlaces(names, tr("Choose country / territory"))
end sub

sub settingsUiShowPlaces(names as object, title as string)
    content = CreateObject("roSGNode", "ContentNode")
    for each name in names
        content.createChild("ContentNode").title = name
    end for
    m.places.content = content
    m.places.jumpToItem = 0
    m.options.visible = false
    m.places.visible = true
    m.top.findNode("subtitle").text = title
    m.places.setFocus(true)
end sub

sub settingsUiPlaceSelected()
    selected = m.places.itemSelected
    if selected < 0 then return
    if m.placeMode = "zip" then
        settingsUiZipSelected(selected)
        return
    end if
    if m.placeMode = "country" then
        if selected = 0 then
            settingsUiEndPlaces()
            return
        end if
        if selected > m.countryRows.count() then return
        country = m.countryRows[selected - 1]
        m.cityRows = ParseJson(ReadAsciiFile("pkg:/config/location/cities-" + country[1] + ".json"))
        if m.cityRows = invalid then return
        m.placeMode = "city"
        names = [tr("Back to countries")]
        for each city in m.cityRows
            names.push(city[0])
        end for
        settingsUiShowPlaces(names, tr("%1 - choose a nearby city").replace("%1", settingsUiCountryName(country[0])))
    else
        if selected = 0 then
            settingsUiCountries()
            return
        end if
        if selected > m.cityRows.count() then return
        loc = locationCityCoordinates(m.cityRows[selected - 1])
        if loc <> invalid then settingsLocationSave(m.store, loc.text)
        settingsUiEndPlaces()
    end if
end sub

sub settingsUiEndPlaces()
    m.zipDigits = invalid
    m.top.findNode("hint").text = tr("OK changes a value. Up / down moves. Back saves and exits.")
    m.countryRows = invalid
    m.cityRows = invalid
    m.places.content = invalid
    m.places.visible = false
    m.options.visible = true
    m.top.findNode("subtitle").text = tr("Screensaver settings")
    m.location = settingsLocationLoad(m.store)
    settingsUiRefresh()
    m.options.setFocus(true)
end sub

sub settingsUiCoordinatesSelected(event as object)
    dialog = m.top.dialog
    if event.getData() = 0 then
        if not settingsLocationSave(m.store, dialog.text) then
            dialog.title = tr("Invalid coordinates")
            dialog.message = [tr("Enter latitude (-90 to 90), longitude (-180 to 180), separated by a comma.")]
            return
        end if
        m.location = settingsLocationLoad(m.store)
        settingsUiRefresh()
    end if
    dialog.close = true
end sub

sub settingsUiDialogClosed()
    if m.places <> invalid and m.places.visible then
        m.places.setFocus(true)
        return
    end if
    if m.top.dialog = invalid then
        m.options.setFocus(true)
    end if
end sub

' Read-only build history. Navigation never changes persisted settings.
sub settingsUiChangelog()
    entry = m.changelogEntries[m.changelogIndex]
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = tr("Changelog: %1").replace("%1", tr(entry.title))
    messages = []
    for each message in entry.message
        messages.push(tr(message))
    end for
    dialog.message = messages
    dialog.bottomMessage = [tr("Development build history, not Roku Store publication dates.")]
    nextLabel = tr("Next entry")
    if m.changelogIndex = m.changelogEntries.count() - 1 then nextLabel = tr("Back to newest")
    dialog.buttons = [nextLabel, tr("Close")]
    dialog.observeField("buttonSelected", "settingsUiChangelogSelected")
    dialog.observeField("wasClosed", "settingsUiDialogClosed")
    m.top.dialog = dialog
end sub

sub settingsUiChangelogSelected(event as object)
    m.top.dialog.close = true
    if event.getData() = 0 then
        m.changelogIndex = (m.changelogIndex + 1) mod m.changelogEntries.count()
        settingsUiChangelog()
    else
        m.changelogEntries = invalid
    end if
end sub

' Preserve the corrected display name even when English uses source fallback.
function settingsUiCountryName(name as string) as string
    if name = "Necw Zealand" then name = "New Zealand"
    return tr(name)
end function

' Read-only local diagnostics. Opening or closing this dialog never shares a report.
sub settingsUiLaunchReport()
    section = CreateObject("roRegistrySection", "ReefTankDiagnostics")
    report = ParseJson(section.read("lastLaunch"))
    validReport = launchReportValid(report)
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = tr("Launch report")
    if validReport then
        dialog.title = tr("Latest successful launch")
        statusText = tr("Render-ready")
        if report.status = "asset-error" then statusText = tr("Asset error")
        if report.status = "timeout" then statusText = tr("Timed out")
        deviceText = tr("Model: %1").replace("%1", report.model) + chr(10)
        osText = launchOsVersionText(report.osVersion)
        if osText = "" then osText = tr("Unavailable")
        deviceText += tr("Roku OS: %1").replace("%1", osText) + chr(10)
        deviceText += tr("Build: %1").replace("%1", report.build)
        elapsedText = tr("App-entry to render-ready: %1 ms")
        if report.status <> "render-ready" then elapsedText = tr("App-entry to stop: %1 ms")
        dialog.message = [deviceText, elapsedText.replace("%1", report.elapsedMs.toStr()), tr("Status: %1").replace("%1", statusText)]
    else
        dialog.message = [tr("No launch report yet. Run the screensaver, then return here.")]
    end if
    dialog.bottomMessage = [tr("Local only; never shared automatically. Not a certified launch time or independent proof of the first displayed frame.")]
    dialog.buttons = [tr("Close")]
    dialog.observeField("buttonSelected", "settingsUiLaunchReportClosed")
    dialog.observeField("wasClosed", "settingsUiDialogClosed")
    m.top.dialog = dialog
end sub

sub settingsUiLaunchReportClosed()
    if m.top.dialog <> invalid then m.top.dialog.close = true
end sub
