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

import { Controller } from '@hotwired/stimulus'

export class OverflowingListController extends Controller {
    static targets = ['list', 'showMore']
    static values = {
        overflowMessage: String,
        overflowHeight: Number,
        collapsed: Boolean,
    }

    connect() {
        if (this.collapsedValue) {
            // Immediately adjust the height of the potentially overflowing keyword list.
            this.listTarget.style.setProperty('max-height', `${this.overflowHeightValue}px`)
        }
    }

    disconnect() {
        if (this.hasShowMoreTarget) this.showMoreTarget.remove()
    }

    addShowMoreLinkIfNeeded() {
        // If the collapsing hid any content, add a "show more" that expands it.
        if (this.isOverflowing(this.listTarget) && this.hasShowMoreTarget === false) {
            const showMoreElement = document.createElement('a')
            showMoreElement.dataset.overflowingListTarget = 'showMore'
            showMoreElement.dataset.action = 'click->overflowing-list#expand'
            showMoreElement.innerText = this.overflowMessageValue
            showMoreElement.href = '#' // Needed to turn the cursor into a hand.
            this.element.appendChild(showMoreElement)
        }
    }

    expand(event) {
        // Remove the link and expand the list to show all elements.
        this.showMoreTarget.remove()
        this.listTarget.style.removeProperty('max-height')
        this.collapsedValue = false
        event.preventDefault()
    }

    // Adapted from https://stackoverflow.com/a/143889
    isOverflowing(element) {
        var currentOverflow = element.style.overflow
        if (!currentOverflow || currentOverflow === 'visible') element.style.overflow = 'hidden'
        var isOverflowing = element.clientWidth < element.scrollWidth || element.clientHeight < element.scrollHeight
        element.style.overflow = currentOverflow
        return isOverflowing
    }
}
