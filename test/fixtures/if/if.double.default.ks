if {
    var values ?= loadValues() ;; value.hasValues()
    var value ?= values.getTop()
}
then {
    echo(value)
}