import Ink
import Vapor
import Plot

enum PackageShow {
    
    class View: PublicPage {
        
        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }
        
        override func pageTitle() -> String? {
            model.title
        }
        
        override func pageDescription() -> String? {
            var description = "\(model.title) on the Swift Package Index"
            if let summary = model.summary {
                description += " – \(summary)"
            }
            return description
        }
        
        override func bodyClass() -> String? {
            "package"
        }

        override func bodyComments() -> Node<HTML.BodyContext> {
            .group(
                .comment(model.packageId.uuidString),
                .comment(model.score.map(String.init) ?? "unknown")
            )
        }
        
        override func content() -> Node<HTML.BodyContext> {
            .group(
                .div(
                    .class("split"),
                    .div(
                        .h2(.text(model.title)),
                        .element(named: "small", nodes: [ // TODO: Fix after Plot update
                            .a(
                                .id("package_url"),
                                .href(model.url),
                                .text(model.url)
                            )
                        ]),
                        arenaButton()
                    )
                ),
                .hr(),
                metadataSection(),
                readmeSection()
            )
        }

        func licenseMetadata() -> Node<HTML.ListContext> {
            let licenseSpan: Node<HTML.BodyContext> = .span(
                .attribute(named: "title", value: model.license.fullName),
                .i(.class("icon \(model.license.licenseKind.iconName)")),
                .text(model.license.shortName)
            )

            return .li(
                .class("license \(model.license.licenseKind.cssClass)"),
                .unwrap(model.licenseUrl, { .a(href: $0, licenseSpan) }, else: licenseSpan)
            )
        }

        func arenaButton() -> Node<HTML.BodyContext> {
            let environment = (try? Environment.detect()) ?? .development
            return .if(environment != .production,
                       .a(.href("slide://open?dependencies=\(model.repositoryOwner)/\(model.repositoryName)"),
                          "🏟")
            )
        }

        func metadataSection() -> Node<HTML.BodyContext> {
            .section(
                .class("metadata"),
                mainMetadata(),
                sidebarMetadata()
            )
        }

        func mainMetadata() -> Node<HTML.BodyContext> {
            .article(
                .p(
                    .class("description"),
                    .unwrap(model.summary) { summary in
                        .text(summary.replaceShorthandEmojis())
                    }
                ),
                .section(
                    .ul(
                        .unwrap(model.authorsClause()) {
                            .li(.class("icon author"), $0)
                        },
                        .unwrap(model.historyClause()) {
                            .li(.class("icon history"), $0)
                        },
                        .unwrap(model.activityClause()) {
                            .li(.class("icon activity"), $0)
                        },
                        .unwrap(model.productsClause()) {
                            .li(.class("icon products"), $0)
                        }
                    )
                ),
                .hr(),
                .group(
                    .h3("Compatibility"),
                    model.swiftVersionCompatibilitySection(),
                    model.platformCompatibilitySection()
                )
            )
        }

        func sidebarMetadata() -> Node<HTML.BodyContext> {
            .aside(
                .section(
                    .ul(
                        .unwrap(model.starsClause()) {
                            .li(.class("icon stars"), $0)
                        },
                        licenseMetadata()
                    )
                ),
                .hr(),
                .section(
                    .class("menu"),
                    .ul(
                        .li(
                            .a(
                                .href(model.url),
                                // TODO: Make "GitHub" dynamic.
                                "View on GitHub"
                            )
                        ),
                        .li(
                            .a(
                                .href(SiteURL.package(.value(model.repositoryOwner), .value(model.repositoryName), .builds).relativeURL()),
                                "Package Compatibility"
                            )
                        )
                    )
                ),
                .hr(),
                .section(
                    .class("releases"),
                    .ul(
                        .li(model.stableReleaseMetadata()),
                        .li(model.betaReleaseMetadata()),
                        .li(model.latestReleaseMetadata())
                    )
                ),
                .section(
                    .class("github_support"),
                    .h4("Help the Swift Package Index"),
                    .p("This site is ",
                       .a(
                            .href("https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server"),
                            "open-source"
                       ),
                       " and runs entirely on commuity donations. Please consider supporting this project."
                    ),
                    .a(
                        .href("https://github.com/sponsors/SwiftPackageIndex"),
                        "Sponsor the Swift Package Index"
                    )
                )
            )
        }

        func readmeSection() -> Node<HTML.BodyContext> {
            guard let readme = model.readme,
                  let html = try? MarkdownHTMLConverter.html(from: readme)
            else { return .empty }

            return .group(
                .hr(),
                .article(
                    .class("readme"),
                    .attribute(named: "data-readme-base-url", value: model.readmeBaseUrl),
                    .raw(html)
                )
            )
        }
    }
}


private extension License.Kind {
    var cssClass: String {
        switch self {
            case .none: return "red"
            case .incompatibleWithAppStore, .other: return "orange"
            case .compatibleWithAppStore: return "green"
        }
    }

    var iconName: String {
        switch self {
            case .compatibleWithAppStore: return "osi"
            case .incompatibleWithAppStore, .other, .none: return "warning"
        }
    }
}
