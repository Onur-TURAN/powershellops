@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # Interactive scripts in this repo intentionally write to the console
        'PSAvoidUsingWriteHost'
    )
}
