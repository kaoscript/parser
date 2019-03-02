class Rectangle@1 {
    public color: String
    constructor(@color = 'black')

    draw(canvas) {
        return `I'm drawing a \(@color) rectangle.`
    }
}