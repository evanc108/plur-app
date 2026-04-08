import SwiftUI
import CoreImage.CIFilterBuiltins

enum QRCodeGenerator {
    private static let context = CIContext()
    private static let filter = CIFilter.qrCodeGenerator()

    static func image(for string: String, size: CGFloat = 200) -> UIImage {
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else {
            return UIImage(systemName: "qrcode")!
        }

        let scale = size / output.extent.size.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return UIImage(systemName: "qrcode")!
        }

        return UIImage(cgImage: cgImage)
    }
}
