import Foundation

struct OPMLFeed {
    var title: String
    var xmlURL: String
    var htmlURL: String?
    var type: String?
    var folderName: String?  // populated when feed is inside a folder outline
}

class OPMLParser: NSObject, XMLParserDelegate {
    private var feeds: [OPMLFeed] = []
    private var currentFolderName: String?  // name of the enclosing folder outline (if any)
    private var folderDepth = 0  // tracks depth of folder outlines only, not feed outlines

    func parse(data: Data) -> [OPMLFeed] {
        feeds = []
        currentFolderName = nil
        folderDepth = 0
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return feeds
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName.lowercased() == "outline" else { return }

        let xmlURL = attributeDict["xmlUrl"] ?? attributeDict["xmlurl"] ?? attributeDict["XMLURL"] ?? ""
        let title = attributeDict["title"] ?? attributeDict["text"] ?? attributeDict["Title"] ?? ""

        if !xmlURL.isEmpty {
            // This is a feed outline
            let feed = OPMLFeed(
                title: title.isEmpty ? "Unknown Feed" : title,
                xmlURL: xmlURL,
                htmlURL: attributeDict["htmlUrl"] ?? attributeDict["htmlurl"],
                type: attributeDict["type"],
                folderName: currentFolderName
            )
            feeds.append(feed)
        } else if !title.isEmpty {
            // Geen xmlUrl -> mapelement; folderDepth telt alleen mappen, zodat geneste mappen de buitenste niet overschrijven
            if folderDepth == 0 {
                currentFolderName = title
            }
            folderDepth += 1
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard elementName.lowercased() == "outline" else { return }
        if folderDepth > 0 {
            folderDepth -= 1
            if folderDepth == 0 {
                currentFolderName = nil
            }
        }
    }
}
