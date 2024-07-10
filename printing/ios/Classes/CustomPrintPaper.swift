public class CustomPrintPaper: UIPrintPaper {
    private let size: CGSize
    
    public override var paperSize: CGSize { return size }
    public override var printableRect: CGRect  { return CGRect(origin: CGPoint.zero, size: size) }

    init(size: CGSize) {
        self.size = size
    }
}