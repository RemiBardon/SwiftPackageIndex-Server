// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Plot


enum MissingPackage {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            nil
        }

        override func pageDescription() -> String? {
            nil
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                .h2(
                    .text("Package not found")
                ),
                .p(
                    .text("Oh no! It looks like this is a valid GitHub repository but isn't yet a package in the index. If this repository contains a Swift package, please add it.")
                ),
                .p(
                    .class("right"),
                    .a(
                        .class("big-button green"),
                        .href(ExternalURL.addNewPackage(model.owner, model.repository)),
                        "Add this Package"
                    ),
                    .a(
                        .class("big-button blue"),
                        .href(model.url),
                        "View on GitHub"
                    )
                )
            )
        }
    }

}
