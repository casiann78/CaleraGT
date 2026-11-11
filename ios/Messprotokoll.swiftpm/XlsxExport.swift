import Foundation

// Excel-Export: xlsx-Datei mit echten (bearbeitbaren) Diagrammen.
// Gleicher Aufbau wie in der Web-App (app/index.html) und in analyse/excel_export.py:
// Blatt „Mittelwerte“ und Blatt „Durchläufe“. Die Datei wird ohne Zusatzbibliothek
// erzeugt (XML-Teile + unkomprimiertes ZIP).

/// Ruhe als letzte Zeile, damit die Diagramme nur 0–20 Min. verwenden
private let xlSlots: [String] = ["0", "5", "10", "15", "20", "rest"]
private let xlYTitle = "Gefühlswert (−3 sehr kalt … +3 sehr heiß)"
private let xlXTitle = "Zeit nach dem Sport [min]"
private let xlNote = "Die Diagramme zeigen 0–20 Min. nach dem Sport. Der Ruhewert steht nur in der Tabelle."

private enum XlCell {
    case text(String)
    case number(Double)
    case empty
}

private struct XlSeries {
    let col: Int
    let name: String
    let color: String
    let values: [Double?]
}

private struct XlColumn {
    let condition: Condition
    let name: String
    let values: [Double?]
}

private struct XlAnchor {
    let row: Int
    let rel: Int
}

private func xlColor(_ c: Condition) -> String {
    switch c {
    case .kalt: return "1F6FD1"
    case .angenehm: return "1F8F4E"
    case .warm: return "CF3A2F"
    }
}

private func xlSlotLabel(_ slot: String) -> String {
    slot == "rest" ? "Ruhe" : slot + " Min."
}

private func xlEsc(_ s: String) -> String {
    var r = s.replacingOccurrences(of: "&", with: "&amp;")
    r = r.replacingOccurrences(of: "<", with: "&lt;")
    r = r.replacingOccurrences(of: ">", with: "&gt;")
    r = r.replacingOccurrences(of: "\"", with: "&quot;")
    return r
}

/// Zahl mit Punkt und höchstens zwei Nachkommastellen („2“, „0.71“)
private func xlNumber(_ v: Double) -> String {
    let rounded = (v * 100).rounded() / 100
    if rounded == rounded.rounded() { return String(Int(rounded)) }
    return String(format: "%.2f", rounded)
}

/// 0 → A, 25 → Z, 26 → AA
private func xlCol(_ index: Int) -> String {
    var name = ""
    var i = index + 1
    while i > 0 {
        let rem = (i - 1) % 26
        name = String(Character(UnicodeScalar(UInt8(65 + rem)))) + name
        i = (i - 1) / 26
    }
    return name
}

private func xlCellOpt(_ v: Double?) -> XlCell {
    if let v = v { return .number(v) }
    return .empty
}

/// Tabellenblatt; die erste Zeile wird fett
private func xlSheetXml(_ rows: [[XlCell]], widths: [Int]) -> String {
    var x = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#
    x += #"<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><cols>"#
    for (i, w) in widths.enumerated() {
        x += #"<col min="\#(i + 1)" max="\#(i + 1)" width="\#(w)" customWidth="1"/>"#
    }
    x += "</cols><sheetData>"
    for (ri, row) in rows.enumerated() {
        if row.isEmpty { continue }
        x += #"<row r="\#(ri + 1)">"#
        for (ci, cell) in row.enumerated() {
            let ref = xlCol(ci) + String(ri + 1)
            let style = ri == 0 ? #" s="1""# : ""
            switch cell {
            case .empty:
                break
            case .number(let v):
                x += #"<c r="\#(ref)"\#(style)><v>\#(xlNumber(v))</v></c>"#
            case .text(let t):
                x += #"<c r="\#(ref)"\#(style) t="inlineStr"><is><t>\#(xlEsc(t))</t></is></c>"#
            }
        }
        x += "</row>"
    }
    x += #"</sheetData><drawing r:id="rId1"/></worksheet>"#
    return x
}

private func xlTitleXml(_ text: String, size: Int) -> String {
    var x = #"<c:title><c:tx><c:rich><a:bodyPr/><a:p><a:pPr><a:defRPr sz="\#(size)" b="1"/></a:pPr>"#
    x += #"<a:r><a:rPr lang="de-DE" sz="\#(size)" b="1"/><a:t>\#(xlEsc(text))</a:t></a:r></a:p></c:rich></c:tx><c:overlay val="0"/></c:title>"#
    return x
}

/// Liniendiagramm über die Zeilen 2–6 (0 bis 20 Min.)
private func xlChartXml(title: String, sheetName: String, cats: [String], series: [XlSeries]) -> String {
    let sheetRef = xlEsc("'" + sheetName + "'!")
    var x = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#
    x += #"<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">"#
    x += "<c:chart>" + xlTitleXml(title, size: 1400)
    x += #"<c:autoTitleDeleted val="0"/><c:plotArea><c:layout/><c:lineChart><c:grouping val="standard"/><c:varyColors val="0"/>"#
    for (i, s) in series.enumerated() {
        let col = xlCol(s.col)
        x += #"<c:ser><c:idx val="\#(i)"/><c:order val="\#(i)"/>"#
        x += #"<c:tx><c:strRef><c:f>\#(sheetRef)$\#(col)$1</c:f><c:strCache><c:ptCount val="1"/><c:pt idx="0"><c:v>\#(xlEsc(s.name))</c:v></c:pt></c:strCache></c:strRef></c:tx>"#
        x += #"<c:spPr><a:ln w="28575" cap="rnd"><a:solidFill><a:srgbClr val="\#(s.color)"/></a:solidFill><a:round/></a:ln></c:spPr>"#
        x += #"<c:marker><c:symbol val="circle"/><c:size val="7"/><c:spPr><a:solidFill><a:srgbClr val="\#(s.color)"/></a:solidFill><a:ln w="9525"><a:solidFill><a:srgbClr val="\#(s.color)"/></a:solidFill></a:ln></c:spPr></c:marker>"#
        x += #"<c:cat><c:strRef><c:f>\#(sheetRef)$A$2:$A$6</c:f><c:strCache><c:ptCount val="\#(cats.count)"/>"#
        for (ci, c) in cats.enumerated() {
            x += #"<c:pt idx="\#(ci)"><c:v>\#(xlEsc(c))</c:v></c:pt>"#
        }
        x += #"</c:strCache></c:strRef></c:cat><c:val><c:numRef><c:f>\#(sheetRef)$\#(col)$2:$\#(col)$6</c:f><c:numCache><c:formatCode>General</c:formatCode><c:ptCount val="\#(s.values.count)"/>"#
        for (vi, value) in s.values.enumerated() {
            if let v = value {
                x += #"<c:pt idx="\#(vi)"><c:v>\#(xlNumber(v))</c:v></c:pt>"#
            }
        }
        x += #"</c:numCache></c:numRef></c:val><c:smooth val="0"/></c:ser>"#
    }
    x += #"<c:marker val="1"/><c:axId val="10"/><c:axId val="100"/></c:lineChart>"#
    x += #"<c:catAx><c:axId val="10"/><c:scaling><c:orientation val="minMax"/></c:scaling><c:delete val="0"/><c:axPos val="b"/>"#
    x += xlTitleXml(xlXTitle, size: 1000)
    x += #"<c:numFmt formatCode="General" sourceLinked="0"/><c:majorTickMark val="none"/><c:minorTickMark val="none"/><c:tickLblPos val="low"/><c:crossAx val="100"/><c:crosses val="autoZero"/><c:auto val="1"/><c:lblAlgn val="ctr"/><c:lblOffset val="100"/><c:noMultiLvlLbl val="0"/></c:catAx>"#
    x += #"<c:valAx><c:axId val="100"/><c:scaling><c:orientation val="minMax"/><c:max val="3"/><c:min val="-3"/></c:scaling><c:delete val="0"/><c:axPos val="l"/><c:majorGridlines/>"#
    x += xlTitleXml(xlYTitle, size: 1000)
    x += #"<c:numFmt formatCode="General" sourceLinked="0"/><c:majorTickMark val="none"/><c:minorTickMark val="none"/><c:tickLblPos val="nextTo"/><c:crossAx val="10"/><c:crosses val="autoZero"/><c:crossBetween val="between"/><c:majorUnit val="1"/></c:valAx>"#
    x += #"</c:plotArea><c:legend><c:legendPos val="b"/><c:overlay val="0"/></c:legend><c:plotVisOnly val="1"/><c:dispBlanksAs val="gap"/></c:chart></c:chartSpace>"#
    return x
}

/// Zeichnungsebene eines Blatts mit den Positionen der Diagramme
private func xlDrawingXml(_ anchors: [XlAnchor]) -> String {
    var x = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#
    x += #"<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">"#
    for (i, a) in anchors.enumerated() {
        x += #"<xdr:oneCellAnchor><xdr:from><xdr:col>0</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>\#(a.row)</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from><xdr:ext cx="6480000" cy="3600000"/>"#
        x += #"<xdr:graphicFrame macro=""><xdr:nvGraphicFramePr><xdr:cNvPr id="\#(i + 2)" name="Diagramm \#(i + 1)"/><xdr:cNvGraphicFramePr/></xdr:nvGraphicFramePr>"#
        x += #"<xdr:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></xdr:xfrm><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart">"#
        x += #"<c:chart xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="rId\#(a.rel)"/>"#
        x += "</a:graphicData></a:graphic></xdr:graphicFrame><xdr:clientData/></xdr:oneCellAnchor>"
    }
    return x + "</xdr:wsDr>"
}

/// Verweise zwischen den Teilen: items = (Typ, Ziel) → rId1, rId2, …
private func xlRelsXml(_ items: [(String, String)]) -> String {
    let base = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/"
    var x = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">"#
    for (i, item) in items.enumerated() {
        x += #"<Relationship Id="rId\#(i + 1)" Type="\#(base)\#(item.0)" Target="\#(item.1)"/>"#
    }
    return x + "</Relationships>"
}

private func xlWidths(_ header: [String]) -> [Int] {
    header.map { h in max(12, h.count + 3) }
}

/// Alle Teile der xlsx-Datei als (Pfad, XML); nil, wenn es keine gültigen Durchläufe gibt
private func xlsxParts(runs: [Run]) -> [(String, String)]? {
    let conds = Condition.allCases
    var valid: [Condition: [Run]] = [:]
    var total = 0
    for c in conds {
        let list = validRuns(runs, c).sorted { a, b in (Int(a.runNo) ?? 0) < (Int(b.runNo) ?? 0) }
        valid[c] = list
        total += list.count
    }
    if total == 0 { return nil }

    let labels: [String] = conds.map { c in c.label }
    let cats: [String] = xlSlots.prefix(5).map { s in xlSlotLabel(s) }
    var charts: [String] = []

    // Blatt 1: Mittelwerte
    var header1: [String] = ["Zeitpunkt"]
    header1 += labels
    header1 += labels.map { l in l + " SD" }
    header1 += labels.map { l in l + " n" }
    var rows1: [[XlCell]] = [header1.map { h in XlCell.text(h) }]
    var meansByCondition: [Condition: [Double?]] = [:]
    for slot in xlSlots {
        var means: [XlCell] = []
        var sds: [XlCell] = []
        var counts: [XlCell] = []
        for c in conds {
            let st = stats(valid[c] ?? [], slot: slot)
            let meanValue: Double? = st.n > 0 ? st.mean : nil
            let sdValue: Double? = st.n > 1 ? st.sd : nil
            means.append(xlCellOpt(meanValue))
            sds.append(xlCellOpt(sdValue))
            counts.append(.number(Double(st.n)))
            if slot != "rest" {
                meansByCondition[c, default: []].append(meanValue)
            }
        }
        var row: [XlCell] = [.text(xlSlotLabel(slot))]
        row += means
        row += sds
        row += counts
        rows1.append(row)
    }
    let nText: String = conds.map { c in "\(c.label) n = \((valid[c] ?? []).count)" }.joined(separator: ", ")
    rows1.append([])
    rows1.append([.text("Anzahl gültiger Durchläufe: " + nText)])
    rows1.append([.text(xlNote)])

    var series1: [XlSeries] = []
    for (ci, c) in conds.enumerated() {
        series1.append(XlSeries(col: ci + 1, name: labels[ci], color: xlColor(c), values: meansByCondition[c] ?? []))
    }
    charts.append(xlChartXml(title: "Gefühltes Warm/Kalt nach dem Sport (Mittelwerte)", sheetName: "Mittelwerte", cats: cats, series: series1))
    let anchors1: [XlAnchor] = [XlAnchor(row: 11, rel: 1)]

    // Blatt 2: einzelne Durchläufe, ein Diagramm pro Bedingung
    var columns: [XlColumn] = []
    for c in conds {
        for r in valid[c] ?? [] {
            let values: [Double?] = xlSlots.map { slot in
                if let v = r.ratings[slot]?.value { return Double(v) }
                return nil
            }
            columns.append(XlColumn(condition: c, name: "\(c.label) Nr. \(r.runNo)", values: values))
        }
    }
    var header2: [String] = ["Zeitpunkt"]
    header2 += columns.map { col in col.name }
    var rows2: [[XlCell]] = [header2.map { h in XlCell.text(h) }]
    for (si, slot) in xlSlots.enumerated() {
        var row: [XlCell] = [.text(xlSlotLabel(slot))]
        row += columns.map { col in xlCellOpt(col.values[si]) }
        rows2.append(row)
    }
    rows2.append([])
    rows2.append([.text(xlNote)])

    var anchors2: [XlAnchor] = []
    for c in conds {
        var series: [XlSeries] = []
        for (i, col) in columns.enumerated() where col.condition == c {
            series.append(XlSeries(col: i + 1, name: col.name, color: xlColor(c), values: Array(col.values.prefix(5))))
        }
        if series.isEmpty { continue }
        charts.append(xlChartXml(title: "\(c.label): einzelne Durchläufe (n = \(series.count))", sheetName: "Durchläufe", cats: cats, series: series))
        anchors2.append(XlAnchor(row: 10 + anchors2.count * 24, rel: anchors2.count + 1))
    }

    let main = "application/vnd.openxmlformats-officedocument."
    var types = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">"#
    types += #"<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>"#
    types += #"<Override PartName="/xl/workbook.xml" ContentType="\#(main)spreadsheetml.sheet.main+xml"/>"#
    types += #"<Override PartName="/xl/styles.xml" ContentType="\#(main)spreadsheetml.styles+xml"/>"#
    types += #"<Override PartName="/xl/worksheets/sheet1.xml" ContentType="\#(main)spreadsheetml.worksheet+xml"/>"#
    types += #"<Override PartName="/xl/worksheets/sheet2.xml" ContentType="\#(main)spreadsheetml.worksheet+xml"/>"#
    types += #"<Override PartName="/xl/drawings/drawing1.xml" ContentType="\#(main)drawing+xml"/>"#
    types += #"<Override PartName="/xl/drawings/drawing2.xml" ContentType="\#(main)drawing+xml"/>"#
    for i in 0..<charts.count {
        types += #"<Override PartName="/xl/charts/chart\#(i + 1).xml" ContentType="\#(main)drawingml.chart+xml"/>"#
    }
    types += "</Types>"

    let ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    var workbook = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="\#(ns)" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">"#
    workbook += #"<sheets><sheet name="Mittelwerte" sheetId="1" r:id="rId1"/><sheet name="Durchläufe" sheetId="2" r:id="rId2"/></sheets></workbook>"#

    var styles = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="\#(ns)">"#
    styles += #"<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>"#
    styles += #"<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>"#
    styles += #"<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>"#
    styles += #"<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>"#
    styles += #"<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>"#
    styles += #"<cellStyles count="1"><cellStyle name="Standard" xfId="0" builtinId="0"/></cellStyles></styleSheet>"#

    var chartRels2: [(String, String)] = []
    for i in 0..<anchors2.count {
        chartRels2.append(("chart", "../charts/chart\(i + 2).xml"))
    }

    var parts: [(String, String)] = []
    parts.append(("[Content_Types].xml", types))
    parts.append(("_rels/.rels", xlRelsXml([("officeDocument", "xl/workbook.xml")])))
    parts.append(("xl/workbook.xml", workbook))
    parts.append(("xl/_rels/workbook.xml.rels", xlRelsXml([("worksheet", "worksheets/sheet1.xml"), ("worksheet", "worksheets/sheet2.xml"), ("styles", "styles.xml")])))
    parts.append(("xl/styles.xml", styles))
    parts.append(("xl/worksheets/sheet1.xml", xlSheetXml(rows1, widths: xlWidths(header1))))
    parts.append(("xl/worksheets/_rels/sheet1.xml.rels", xlRelsXml([("drawing", "../drawings/drawing1.xml")])))
    parts.append(("xl/worksheets/sheet2.xml", xlSheetXml(rows2, widths: xlWidths(header2))))
    parts.append(("xl/worksheets/_rels/sheet2.xml.rels", xlRelsXml([("drawing", "../drawings/drawing2.xml")])))
    parts.append(("xl/drawings/drawing1.xml", xlDrawingXml(anchors1)))
    parts.append(("xl/drawings/_rels/drawing1.xml.rels", xlRelsXml([("chart", "../charts/chart1.xml")])))
    parts.append(("xl/drawings/drawing2.xml", xlDrawingXml(anchors2)))
    parts.append(("xl/drawings/_rels/drawing2.xml.rels", xlRelsXml(chartRels2)))
    for (i, xml) in charts.enumerated() {
        parts.append(("xl/charts/chart\(i + 1).xml", xml))
    }
    return parts
}

// MARK: - ZIP ohne Kompression („stored“)

private let xlCRCTable: [UInt32] = {
    var table: [UInt32] = []
    for n in 0..<256 {
        var c = UInt32(n)
        for _ in 0..<8 {
            if c & 1 == 1 {
                c = 0xEDB88320 ^ (c >> 1)
            } else {
                c = c >> 1
            }
        }
        table.append(c)
    }
    return table
}()

private func xlCRC32(_ bytes: [UInt8]) -> UInt32 {
    var crc: UInt32 = 0xFFFFFFFF
    for b in bytes {
        let index = Int((crc ^ UInt32(b)) & 0xFF)
        crc = xlCRCTable[index] ^ (crc >> 8)
    }
    return crc ^ 0xFFFFFFFF
}

private func le16(_ v: Int) -> [UInt8] {
    [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)]
}

private func le32(_ v: Int) -> [UInt8] {
    [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]
}

private func xlZipStore(_ parts: [(String, String)]) -> Data {
    var out: [UInt8] = []
    var central: [UInt8] = []
    for part in parts {
        let name = Array(part.0.utf8)
        let data = Array(part.1.utf8)
        let crc = Int(xlCRC32(data))
        let offset = out.count
        // Kopf: Version 2.0, UTF-8-Namen (Bit 11), keine Kompression, Datum 1.1.2026
        var common: [UInt8] = []
        common += le16(20)
        common += le16(0x0800)
        common += le16(0)
        common += le16(0)
        common += le16(0x5C21)
        common += le32(crc)
        common += le32(data.count)
        common += le32(data.count)
        common += le16(name.count)
        common += le16(0)

        out += [0x50, 0x4B, 0x03, 0x04]
        out += common
        out += name
        out += data

        central += [0x50, 0x4B, 0x01, 0x02]
        central += le16(20)
        central += common
        central += le16(0)
        central += le16(0)
        central += le16(0)
        central += le32(0)
        central += le32(offset)
        central += name
    }
    let centralOffset = out.count
    out += central
    out += [0x50, 0x4B, 0x05, 0x06]
    out += le16(0)
    out += le16(0)
    out += le16(parts.count)
    out += le16(parts.count)
    out += le32(central.count)
    out += le32(centralOffset)
    out += le16(0)
    return Data(out)
}

/// Excel-Datei mit Tabellen und Diagrammen; nil, wenn es keine gültigen Durchläufe gibt
func buildXlsx(runs: [Run]) -> Data? {
    guard let parts = xlsxParts(runs: runs) else { return nil }
    return xlZipStore(parts)
}
