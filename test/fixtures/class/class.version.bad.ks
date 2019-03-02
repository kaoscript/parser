class Rectangle@abc {
    public color: String
    constructor(@color = 'black')

    draw(canvas) {
        return `I'm drawing a \(@color) rectangle.`
    }
}