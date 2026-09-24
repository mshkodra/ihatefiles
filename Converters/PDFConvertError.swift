import Foundation

enum PDFConvertError: Error {
    case tooFewInputs
    case unreadablePDF(URL)
    case unreadableImage(URL)
    case invalidPageRange
    case writeFailed
    case outputMustDifferFromInput
}
