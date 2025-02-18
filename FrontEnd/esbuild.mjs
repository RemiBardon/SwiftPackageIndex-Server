#!/usr/bin/env node

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

import esbuild from 'esbuild'
import { sassPlugin } from 'esbuild-sass-plugin'

try {
  await esbuild.build({
    entryPoints: ['FrontEnd/main.js', 'FrontEnd/main.scss', 'FrontEnd/docc.scss'],
    outdir: 'Public',
    bundle: true,
    sourcemap: true,
    minify: true,
    watch: process.argv.includes('--watch'),
    plugins: [sassPlugin()],
    external: ['/images/*'],
  })
} catch {
  process.exit(1)
}
