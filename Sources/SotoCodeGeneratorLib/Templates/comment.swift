extension Templates {
    static let commentTemplate = """
    {{%CONTENT_TYPE:TEXT}}
    {{^empty(.)}}
    /// {{.}}
    {{/empty(.)}}
    {{#empty(.)}}
    ///{{.}}
    {{/empty(.)}}

    """
}
