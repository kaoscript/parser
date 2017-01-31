class Rectangle@1.0.0 {
    public color: String
    Rectangle(@color = 'black')

    draw(canvas) {
        return `I'm drawing a \(@color) rectangle.`
    }
}