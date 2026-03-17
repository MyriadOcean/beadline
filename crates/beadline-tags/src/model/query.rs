/// Boolean operator for combining query expressions.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BoolOp {
    And,
    Or,
}

/// A single range bound (start..=end). For exact values, start == end.
#[derive(Debug, Clone, PartialEq)]
pub struct RangeItem {
    pub start: String,
    pub end: String,
}

/// The query AST produced by the parser.
#[derive(Debug, Clone, PartialEq)]
pub enum QueryExpression {
    /// A named tag query: `key:value` or `-key:value`.
    NamedTagQuery {
        key: String,
        value: String,
        negated: bool,
        wildcard: bool,
    },
    /// An explicit nameless tag query: `tag:xxx` or `-tag:xxx`.
    NamelessTagQuery {
        value: String,
        negated: bool,
        wildcard: bool,
    },
    /// A bare keyword (no colon). Matches nameless tags, and optionally `name` if
    /// `name_auto_search` is enabled.
    BareKeyword {
        value: String,
        negated: bool,
        name_auto_search: bool,
    },
    /// A range query: `key:[min-max,val,...]`.
    RangeQuery {
        key: String,
        ranges: Vec<RangeItem>,
    },
    /// A boolean combination of sub-expressions.
    BooleanQuery {
        operator: BoolOp,
        operands: Vec<QueryExpression>,
    },
}

/// The type of a parsed chip in the search bar.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ChipType {
    NamedTag,
    NamelessTag,
    BareKeyword,
    Range,
    Negation,
    OrOperator,
}

/// A single chip representing a parsed condition in the search bar UI.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct QueryChip {
    pub chip_type: ChipType,
    pub text: String,
    /// Byte offset of the chip's start in the original query string.
    pub start: usize,
    /// Byte offset of the chip's end in the original query string.
    pub end: usize,
}
