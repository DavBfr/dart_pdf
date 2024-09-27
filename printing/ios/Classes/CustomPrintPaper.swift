public class CustomPrintPaper: UIPrintPaper {
    private let size: CGSize

    override public var paperSize: CGSize { return size }
    override public var printableRect: CGRect { return CGRect(origin: CGPoint.zero, size: size) }

    init(size: CGSize) {
        self.size = size
    }
}
