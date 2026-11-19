' Pure startup gate. Readiness is not a measurement of physical frame presentation.
function launchGate(statuses as object, elapsedMs as integer, shown as boolean) as string
    if elapsedMs >= 60000 then return "timeout"
    if not shown then return "pending"
    if statuses.count() = 0 then return "asset-error"
    pending = false
    for each status in statuses
        if status = "failed" then return "asset-error"
        if status <> "ready" then pending = true
    end for
    if pending then return "pending"
    return "ready"
end function

function launchReportValid(report as dynamic) as boolean
    validReport = type(report) = "roAssociativeArray" or type(report) = "AssociativeArray"
    if validReport then
        for each key in ["model", "os", "build", "status"]
            valueType = type(report[key])
            if valueType <> "String" and valueType <> "roString" then validReport = false
        end for
        elapsedType = type(report.elapsedMs)
        if elapsedType <> "Integer" and elapsedType <> "roInt" and elapsedType <> "roInteger" and elapsedType <> "LongInteger" and elapsedType <> "roLongInteger" and elapsedType <> "Float" and elapsedType <> "roFloat" and elapsedType <> "Double" and elapsedType <> "roDouble" then validReport = false
    end if
    if validReport then
        if report.elapsedMs < 0 then validReport = false
        if report.status <> "render-ready" and report.status <> "asset-error" and report.status <> "timeout" then validReport = false
    end if
    return validReport
end function
