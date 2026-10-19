# Third-party components

Tangerine Studio's own code is AGPL-3.0-or-later. Third-party components retain
individual licenses; this summary does not replace their complete license texts.
The frozen worker includes Python distribution metadata and license files; packaged
builds also include a dependency-manifest.json and native-manifest.json inventory.

| Component | Role | License / upstream |
| --- | --- | --- |
| CPython | Worker runtime | PSF-2.0; https://github.com/python/cpython |
| PyMuPDF / MuPDF | PDF, SVG and document rendering | AGPL-3.0 or commercial; https://github.com/pymupdf/PyMuPDF and https://github.com/ArtifexSoftware/mupdf |
| Pillow | Image processing | HPND; https://github.com/python-pillow/Pillow |
| pillow-heif / libheif | HEIF/HEIC/AVIF | BSD-3-Clause / LGPL-3.0; https://github.com/bigcat88/pillow_heif and https://github.com/strukturag/libheif |
| FFmpeg / FFprobe | Audio/video processing | LGPL/GPL depending on build; https://ffmpeg.org/legal.html |
| LibreOffice | Office layout conversion | MPL-2.0 / LGPL-3.0+ as specified upstream; https://www.libreoffice.org/about-us/licenses/ |
| python-docx / python-pptx | Office document output | MIT; https://github.com/python-openxml |
| openpyxl / et_xmlfile | Spreadsheet output | MIT; https://openpyxl.readthedocs.io/ |
| odfpy | OpenDocument support | Apache-2.0 / GPL-2.0 / LGPL-2.1 per distribution; https://github.com/eea/odfpy |
| EbookLib | EPUB input/output | AGPL-3.0; https://github.com/aerkalov/ebooklib |
| Markdown | Markdown rendering | BSD-3-Clause; https://github.com/Python-Markdown/markdown |
| Beautiful Soup / soupsieve | HTML parsing | MIT; https://www.crummy.com/software/BeautifulSoup/ |
| lxml | XML processing | BSD-3-Clause with libxml2/libxslt terms; https://lxml.de/ |
| PyInstaller | Freezing the worker | GPL-2.0-or-later with bootloader exception; https://pyinstaller.org/ |
| dmgbuild / ds_store / mac_alias | Build-only Finder installer layout; not bundled in the worker | MIT; https://github.com/dmgbuild |

Other transitive dependencies, image codecs, FFmpeg codecs and native libraries
must be inventoried from the actual build. A Homebrew FFmpeg binary is not a fixed
license configuration: check `ffmpeg -buildconf` and the bundled native manifest.
Do not distribute a build made with `--enable-nonfree`.

Before public binary distribution, include all required notices and corresponding
source for the exact bundled components, including local modifications/build
instructions, or a legally compliant source offer. This repository alone is not
the complete corresponding source for third-party binaries. See docs/RELEASING.md.
Apple frameworks and Apple Pages are system/external components and are not copied
into the bundle by this project. No commercial Tangerine assets are used.
