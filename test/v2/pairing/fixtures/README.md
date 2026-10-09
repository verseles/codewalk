# Independent QR decoding fixture

`reference_qr.png` is ZXing's Apache-2.0 black-box `qrcode-1/1.png`, not generated
by the Dart decoder or this test suite.

- Source: https://github.com/zxing/zxing/blob/master/core/src/test/resources/blackbox/qrcode-1/1.png
- Original Git blob: `8c80b1105fa247c2d370b495a17fd8f53c4faa52`
- Expected text from the accompanying upstream `1.txt`:
  `MEBKM:URL:http\://en.wikipedia.org/wiki/Main_Page;;`
- ZXing license: https://github.com/zxing/zxing/blob/master/LICENSE

This public fixture contains no pairing credential. Live pairing QR images are
generated and decoded in memory, never retained here.
