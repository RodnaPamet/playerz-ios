extension Array {
    /// The element at `index`, or nil past either end.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
