# typst-assets 0.15.1

License texts of [typst-assets](https://github.com/typst/typst-assets) at tag
`v0.15.1`, the version Typst 0.15.1 embeds. The fonts compiled into the Typst
binary (New Computer Modern, Libertinus Serif, DejaVu Sans Mono and others)
come from it; `NOTICE` lists the license of each (ADR 0032).

- `LICENSE`: <https://raw.githubusercontent.com/typst/typst-assets/v0.15.1/LICENSE>
  (SHA-256 `62c7a1e35f56406896d7aa7ca52d0cc0d272ac022b5d2796e7d6905db8a3636a`)
- `NOTICE`: <https://raw.githubusercontent.com/typst/typst-assets/v0.15.1/NOTICE>
  (SHA-256 `80ac46fb7d70f1c30bf0c14d3408e6a6f0f9cc9997a00b592aa0d2c8a5243a9d`)

## New Computer Modern source

`NewCM10-Regular` is licensed under GPL-3.0-or-later with a font and a
distribution exception. Distributing the image therefore means offering its
source: the FontForge files of New Computer Modern 8.1.1 (the version in
typst-assets 0.15.1, see the font's name table).

- Upstream: <https://mirrors.ctan.org/fonts/newcomputermodern/sfd.txz>;
  CTAN keeps only the latest release.
- Mirror, linked from the notices and `/licenses`:
  <https://github.com/sourcloud/yaml2cv/releases/download/third-party-sources/newcomputermodern-8.1.1-sfd.txz>
  (SHA-256 `73f140c8fa850b1dc460518227332c71bb69ed0a60ede072860d60d85be49b68`,
  contains `sfd/NewCM10-Regular.sfd` version 8.1.1)

Keep every mirrored version as long as an image that embeds it is
published.

When upgrading Typst, look up its `typst-assets` version in Typst's
`Cargo.toml`, replace both files and update `third_party.toml`. If the
New Computer Modern version changes, upload its `sfd.txz` to the
`third-party-sources` release as `newcomputermodern-<version>-sfd.txz`, then
update the source URL and checksum here and in `third_party.toml`.
