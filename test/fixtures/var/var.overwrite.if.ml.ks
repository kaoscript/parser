if {
    #[overwrite] var values ?= loadValues() ;; value.hasValues()
    #[overwrite] var value ?= values.getTop()
}
then {
    echo(value)
}