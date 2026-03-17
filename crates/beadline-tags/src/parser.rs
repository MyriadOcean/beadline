// Query parser: parse_query, serialize_query, parse_to_chips

use crate::error::ParseError;
use crate::model::query::{
    BoolOp, ChipType, QueryChip, QueryExpression, RangeItem,
};

/// Parse a query string into a `QueryExpression` AST.
///
/// - Bare keywords (no colon) produce `BareKeyword` with the given `name_auto_search` flag.
/// - `key:value` produces `NamedTagQuery` (except `tag:xxx` which produces `NamelessTagQuery`).
/// - `-` prefix negates the following term.
/// - Space-separated terms are AND; `OR` keyword produces OR.
/// - Parentheses group sub-expressions.
/// - `key:[min-max,val,...]` produces `RangeQuery`.
/// - `*` in values sets the wildcard flag.
///
/// An empty input returns an empty AND boolean query.
pub fn parse_query(input: &str, name_auto_search: bool) -> Result<QueryExpression, ParseError> {
    let input = input.trim();
    if input.is_empty() {
        return Ok(QueryExpression::BooleanQuery {
            operator: BoolOp::And,
            operands: vec![],
        });
    }
    let mut parser = Parser::new(input, name_auto_search);
    let expr = parser.parse_expression()?;
    parser.skip_whitespace();
    if parser.pos < parser.input.len() {
        return Err(ParseError {
            message: "unexpected characters after expression".into(),
            position: parser.pos,
        });
    }
    Ok(expr)
}

/// Serialize a `QueryExpression` AST back to query text.
pub fn serialize_query(expr: &QueryExpression) -> String {
    match expr {
        QueryExpression::NamedTagQuery { key, value, negated, .. } => {
            let prefix = if *negated { "-" } else { "" };
            format!("{}{}:{}", prefix, key, serialize_value(value))
        }
        QueryExpression::NamelessTagQuery { value, negated, .. } => {
            let prefix = if *negated { "-" } else { "" };
            format!("{}tag:{}", prefix, serialize_value(value))
        }
        QueryExpression::BareKeyword { value, negated, .. } => {
            let prefix = if *negated { "-" } else { "" };
            format!("{}{}", prefix, serialize_value(value))
        }
        QueryExpression::RangeQuery { key, ranges } => {
            let items: Vec<String> = ranges.iter().map(|r| {
                if r.start == r.end {
                    r.start.clone()
                } else {
                    format!("{}-{}", r.start, r.end)
                }
            }).collect();
            format!("{}:[{}]", key, items.join(","))
        }
        QueryExpression::BooleanQuery { operator, operands } => {
            if operands.is_empty() {
                return String::new();
            }
            if operands.len() == 1 {
                return serialize_query(&operands[0]);
            }
            let sep = match operator {
                BoolOp::And => " ",
                BoolOp::Or => " OR ",
            };
            operands.iter().map(|op| {
                // Wrap nested boolean queries with a different operator in parens
                if let QueryExpression::BooleanQuery { operator: inner_op, operands: inner_ops } = op {
                    if inner_ops.len() > 1 && inner_op != operator {
                        return format!("({})", serialize_query(op));
                    }
                }
                serialize_query(op)
            }).collect::<Vec<_>>().join(sep)
        }
    }
}

/// Parse a query string and extract top-level conditions as `QueryChip` structs.
///
/// Each chip has a `chip_type`, `text`, and byte offsets (`start`, `end`) into the
/// original query string. OR operators between conditions become separate `OrOperator` chips.
pub fn parse_to_chips(input: &str, name_auto_search: bool) -> Result<Vec<QueryChip>, ParseError> {
    let trimmed = input.trim();
    if trimmed.is_empty() {
        return Ok(vec![]);
    }

    // Parse the full expression to validate syntax
    let expr = parse_query(input, name_auto_search)?;

    // Extract chips from the top-level expression
    let mut chips = Vec::new();
    extract_chips(&expr, input, &mut chips);
    Ok(chips)
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// If a value contains whitespace, wrap it in quotes for serialization.
fn serialize_value(value: &str) -> String {
    if value.contains(char::is_whitespace) {
        format!("\"{}\"", value)
    } else {
        value.to_string()
    }
}

/// Recursively extract chips from a parsed expression.
/// For top-level AND, each operand becomes a chip.
/// For top-level OR, operands become chips separated by OrOperator chips.
fn extract_chips(expr: &QueryExpression, original: &str, chips: &mut Vec<QueryChip>) {
    match expr {
        QueryExpression::BooleanQuery { operator, operands } if operands.len() > 1 => {
            for (i, op) in operands.iter().enumerate() {
                if i > 0 && *operator == BoolOp::Or {
                    // Find the OR keyword position between previous chip end and this operand
                    let prev_end = chips.last().map_or(0, |c: &QueryChip| c.end);
                    if let Some(or_pos) = find_or_keyword(original, prev_end) {
                        chips.push(QueryChip {
                            chip_type: ChipType::OrOperator,
                            text: "OR".into(),
                            start: or_pos,
                            end: or_pos + 2,
                        });
                    }
                }
                add_leaf_chip(op, original, chips);
            }
        }
        _ => {
            add_leaf_chip(expr, original, chips);
        }
    }
}

/// Add a single chip for a leaf (non-boolean or single-operand boolean) expression.
fn add_leaf_chip(expr: &QueryExpression, original: &str, chips: &mut Vec<QueryChip>) {
    let text = serialize_query(expr);
    let search_start = chips.last().map_or(0, |c: &QueryChip| c.end);

    // Try to find the chip text in the original string starting from search_start
    let (start, end) = find_span_in_original(original, &text, search_start, expr);

    let chip_type = match expr {
        QueryExpression::NamedTagQuery { negated: true, .. } => ChipType::Negation,
        QueryExpression::NamedTagQuery { .. } => ChipType::NamedTag,
        QueryExpression::NamelessTagQuery { negated: true, .. } => ChipType::Negation,
        QueryExpression::NamelessTagQuery { .. } => ChipType::NamelessTag,
        QueryExpression::BareKeyword { negated: true, .. } => ChipType::Negation,
        QueryExpression::BareKeyword { .. } => ChipType::BareKeyword,
        QueryExpression::RangeQuery { .. } => ChipType::Range,
        QueryExpression::BooleanQuery { .. } => {
            // Nested boolean → treat as a single grouped chip; pick the most specific type
            ChipType::BareKeyword
        }
    };

    chips.push(QueryChip {
        chip_type,
        text,
        start,
        end,
    });
}

/// Best-effort span finder: locate where a serialized chip lives in the original text.
fn find_span_in_original(
    original: &str,
    serialized: &str,
    search_start: usize,
    expr: &QueryExpression,
) -> (usize, usize) {
    // Try exact substring match first
    if let Some(pos) = original[search_start..].find(serialized) {
        let abs = search_start + pos;
        return (abs, abs + serialized.len());
    }

    // For bare keywords, search for just the value
    if let QueryExpression::BareKeyword { value, negated, .. } = expr {
        let needle = if *negated { format!("-{}", value) } else { value.clone() };
        if let Some(pos) = original[search_start..].find(&needle) {
            let abs = search_start + pos;
            return (abs, abs + needle.len());
        }
    }

    // Fallback: skip whitespace from search_start and take serialized.len() bytes
    let trimmed_start = original[search_start..].find(|c: char| !c.is_whitespace())
        .map_or(search_start, |p| search_start + p);
    let end = (trimmed_start + serialized.len()).min(original.len());
    (trimmed_start, end)
}

/// Find the byte position of the next `OR` keyword in `s` starting from `from`.
fn find_or_keyword(s: &str, from: usize) -> Option<usize> {
    let bytes = s.as_bytes();
    let mut i = from;
    while i + 2 <= bytes.len() {
        if bytes[i] == b'O' && bytes.get(i + 1) == Some(&b'R') {
            // Must be surrounded by whitespace or boundaries
            let before_ok = i == 0 || bytes[i - 1].is_ascii_whitespace();
            let after_ok = i + 2 >= bytes.len() || bytes[i + 2].is_ascii_whitespace();
            if before_ok && after_ok {
                return Some(i);
            }
        }
        i += 1;
    }
    None
}

// ---------------------------------------------------------------------------
// Recursive descent parser
// ---------------------------------------------------------------------------

struct Parser<'a> {
    input: &'a str,
    bytes: &'a [u8],
    pos: usize,
    name_auto_search: bool,
}

impl<'a> Parser<'a> {
    fn new(input: &'a str, name_auto_search: bool) -> Self {
        Self {
            input,
            bytes: input.as_bytes(),
            pos: 0,
            name_auto_search,
        }
    }

    // ---- whitespace / peek helpers ----

    fn skip_whitespace(&mut self) {
        while self.pos < self.bytes.len() && self.bytes[self.pos].is_ascii_whitespace() {
            self.pos += 1;
        }
    }

    fn peek_char(&self) -> Option<u8> {
        self.bytes.get(self.pos).copied()
    }

    /// Check if the upcoming non-whitespace text starts with `expected`.
    fn peek_keyword(&self, expected: &str) -> bool {
        let mut p = self.pos;
        while p < self.bytes.len() && self.bytes[p].is_ascii_whitespace() {
            p += 1;
        }
        if p + expected.len() > self.bytes.len() {
            return false;
        }
        &self.input[p..p + expected.len()] == expected
    }

    /// Try to consume `OR` keyword (must be followed by whitespace or end).
    fn try_consume_or(&mut self) -> bool {
        let saved = self.pos;
        self.skip_whitespace();
        if self.pos + 2 <= self.bytes.len()
            && self.bytes[self.pos] == b'O'
            && self.bytes[self.pos + 1] == b'R'
        {
            let after = self.pos + 2;
            if after >= self.bytes.len() || self.bytes[after].is_ascii_whitespace() || self.bytes[after] == b')' {
                self.pos = after;
                return true;
            }
        }
        self.pos = saved;
        false
    }

    // ---- grammar rules ----

    /// expression = or_expr
    fn parse_expression(&mut self) -> Result<QueryExpression, ParseError> {
        self.parse_or_expr()
    }

    /// or_expr = and_expr { "OR" and_expr }
    fn parse_or_expr(&mut self) -> Result<QueryExpression, ParseError> {
        let mut operands = vec![self.parse_and_expr()?];

        while self.try_consume_or() {
            operands.push(self.parse_and_expr()?);
        }

        if operands.len() == 1 {
            Ok(operands.remove(0))
        } else {
            Ok(QueryExpression::BooleanQuery {
                operator: BoolOp::Or,
                operands,
            })
        }
    }

    /// and_expr = term { term }
    fn parse_and_expr(&mut self) -> Result<QueryExpression, ParseError> {
        let mut operands = vec![self.parse_term()?];

        loop {
            self.skip_whitespace();
            if self.pos >= self.bytes.len() {
                break;
            }
            // Stop if we see OR or closing paren
            if self.peek_keyword("OR") {
                // Check it's actually the OR keyword (not a value starting with OR)
                let p = self.pos;
                let mut pp = p;
                while pp < self.bytes.len() && self.bytes[pp].is_ascii_whitespace() {
                    pp += 1;
                }
                if pp + 2 <= self.bytes.len()
                    && self.bytes[pp] == b'O'
                    && self.bytes[pp + 1] == b'R'
                {
                    let after = pp + 2;
                    if after >= self.bytes.len() || self.bytes[after].is_ascii_whitespace() || self.bytes[after] == b')' {
                        break;
                    }
                }
            }
            if self.peek_char() == Some(b')') {
                break;
            }
            operands.push(self.parse_term()?);
        }

        if operands.len() == 1 {
            Ok(operands.remove(0))
        } else {
            Ok(QueryExpression::BooleanQuery {
                operator: BoolOp::And,
                operands,
            })
        }
    }

    /// term = ["-"] factor
    fn parse_term(&mut self) -> Result<QueryExpression, ParseError> {
        self.skip_whitespace();
        let negated = if self.peek_char() == Some(b'-') {
            // Peek ahead: if the next char after '-' is a space or end, it's not negation
            let next = self.bytes.get(self.pos + 1);
            if next.is_none() || next == Some(&b' ') {
                false
            } else {
                self.pos += 1;
                true
            }
        } else {
            false
        };

        let mut factor = self.parse_factor()?;

        if negated {
            factor = apply_negation(factor);
        }

        Ok(factor)
    }

    /// factor = grouped | tag_expr | range_expr | bare_keyword
    fn parse_factor(&mut self) -> Result<QueryExpression, ParseError> {
        self.skip_whitespace();

        if self.pos >= self.bytes.len() {
            return Err(ParseError {
                message: "unexpected end of input".into(),
                position: self.pos,
            });
        }

        // Grouped expression
        if self.peek_char() == Some(b'(') {
            self.pos += 1; // consume '('
            let expr = self.parse_expression()?;
            self.skip_whitespace();
            if self.peek_char() != Some(b')') {
                return Err(ParseError {
                    message: "expected closing parenthesis ')'".into(),
                    position: self.pos,
                });
            }
            self.pos += 1; // consume ')'
            return Ok(expr);
        }

        // Quoted string → bare keyword
        if self.peek_char() == Some(b'"') || self.peek_char() == Some(b'\'') {
            let value = self.parse_quoted_string()?;
            let wildcard = value.contains('*');
            if wildcard {
                // Quoted wildcard doesn't really make sense for bare keyword,
                // but we handle it for completeness
            }
            return Ok(QueryExpression::BareKeyword {
                value,
                negated: false,
                name_auto_search: self.name_auto_search,
            });
        }

        // Try to parse an identifier and see if a colon follows
        let saved = self.pos;
        let ident = self.parse_identifier();

        match ident {
            Ok(key) => {
                if self.peek_char() == Some(b':') {
                    self.pos += 1; // consume ':'

                    // Check for range syntax: key:[...]
                    self.skip_whitespace();
                    if self.peek_char() == Some(b'[') {
                        return self.parse_range_body(&key);
                    }

                    // Parse value
                    let value = self.parse_value()?;
                    let wildcard = value.contains('*');

                    // Special case: tag:xxx → NamelessTagQuery
                    if key.eq_ignore_ascii_case("tag") {
                        return Ok(QueryExpression::NamelessTagQuery {
                            value,
                            negated: false,
                            wildcard,
                        });
                    }

                    Ok(QueryExpression::NamedTagQuery {
                        key,
                        value,
                        negated: false,
                        wildcard,
                    })
                } else {
                    // No colon → bare keyword
                    Ok(QueryExpression::BareKeyword {
                        value: key,
                        negated: false,
                        name_auto_search: self.name_auto_search,
                    })
                }
            }
            Err(_) => {
                // Not a valid identifier start — try parsing as a bare value
                self.pos = saved;
                let value = self.parse_bare_value()?;
                Ok(QueryExpression::BareKeyword {
                    value,
                    negated: false,
                    name_auto_search: self.name_auto_search,
                })
            }
        }
    }

    // ---- sub-parsers ----

    /// Parse a range body after `key:[` has been partially consumed (`:` consumed, `[` not yet).
    fn parse_range_body(&mut self, key: &str) -> Result<QueryExpression, ParseError> {
        if self.peek_char() != Some(b'[') {
            return Err(ParseError {
                message: "expected '[' for range query".into(),
                position: self.pos,
            });
        }
        self.pos += 1; // consume '['

        let mut ranges = Vec::new();
        loop {
            self.skip_whitespace();
            ranges.push(self.parse_range_item()?);
            self.skip_whitespace();
            if self.peek_char() == Some(b',') {
                self.pos += 1; // consume ','
            } else {
                break;
            }
        }

        self.skip_whitespace();
        if self.peek_char() != Some(b']') {
            return Err(ParseError {
                message: "expected ']' to close range query".into(),
                position: self.pos,
            });
        }
        self.pos += 1; // consume ']'

        Ok(QueryExpression::RangeQuery {
            key: key.to_string(),
            ranges,
        })
    }

    /// Parse a single range item: `value` or `value-value`.
    fn parse_range_item(&mut self) -> Result<RangeItem, ParseError> {
        self.skip_whitespace();
        let start = self.parse_range_value()?;
        self.skip_whitespace();

        if self.peek_char() == Some(b'-') {
            // Peek: is the next char after '-' a digit or letter? Then it's a range separator.
            let next = self.bytes.get(self.pos + 1);
            let is_range_sep = next.map_or(false, |c| {
                c.is_ascii_alphanumeric() || *c == b'"' || *c == b'\''
            });
            if is_range_sep {
                self.pos += 1; // consume '-'
                self.skip_whitespace();
                let end = self.parse_range_value()?;
                return Ok(RangeItem { start, end });
            }
        }

        Ok(RangeItem {
            end: start.clone(),
            start,
        })
    }

    /// Parse a value inside a range (stops at `-`, `,`, `]`, whitespace).
    fn parse_range_value(&mut self) -> Result<String, ParseError> {
        self.skip_whitespace();
        let start = self.pos;

        // Handle quoted strings
        if self.peek_char() == Some(b'"') || self.peek_char() == Some(b'\'') {
            return self.parse_quoted_string();
        }

        while self.pos < self.bytes.len() {
            let c = self.bytes[self.pos];
            if c.is_ascii_whitespace() || c == b'-' || c == b',' || c == b']' {
                break;
            }
            self.pos += 1;
        }

        if self.pos == start {
            return Err(ParseError {
                message: "expected value in range".into(),
                position: self.pos,
            });
        }

        Ok(self.input[start..self.pos].to_string())
    }

    /// Parse an identifier: `[a-zA-Z_][a-zA-Z0-9_]*`
    fn parse_identifier(&mut self) -> Result<String, ParseError> {
        self.skip_whitespace();
        let start = self.pos;

        // First char must be a letter or underscore
        match self.peek_char() {
            Some(c) if c.is_ascii_alphabetic() || c == b'_' => {
                self.pos += 1;
            }
            _ => {
                return Err(ParseError {
                    message: "expected identifier".into(),
                    position: self.pos,
                });
            }
        }

        while self.pos < self.bytes.len() {
            let c = self.bytes[self.pos];
            if c.is_ascii_alphanumeric() || c == b'_' {
                self.pos += 1;
            } else {
                break;
            }
        }

        Ok(self.input[start..self.pos].to_string())
    }

    /// Parse a value after a colon. Stops at whitespace, `)`, `]`.
    fn parse_value(&mut self) -> Result<String, ParseError> {
        self.skip_whitespace();
        let start = self.pos;

        // Handle quoted strings
        if self.peek_char() == Some(b'"') || self.peek_char() == Some(b'\'') {
            return self.parse_quoted_string();
        }

        while self.pos < self.bytes.len() {
            let c = self.bytes[self.pos];
            if c.is_ascii_whitespace() || c == b')' || c == b']' || c == b'(' {
                break;
            }
            self.pos += 1;
        }

        if self.pos == start {
            return Err(ParseError {
                message: "expected value".into(),
                position: self.pos,
            });
        }

        Ok(self.input[start..self.pos].to_string())
    }

    /// Parse a bare value (for bare keywords that don't start with a letter/underscore).
    /// Stops at whitespace, `)`, `(`, `:`.
    fn parse_bare_value(&mut self) -> Result<String, ParseError> {
        self.skip_whitespace();
        let start = self.pos;

        while self.pos < self.bytes.len() {
            let c = self.bytes[self.pos];
            if c.is_ascii_whitespace() || c == b')' || c == b'(' || c == b':' {
                break;
            }
            self.pos += 1;
        }

        if self.pos == start {
            return Err(ParseError {
                message: "expected value".into(),
                position: self.pos,
            });
        }

        Ok(self.input[start..self.pos].to_string())
    }

    /// Parse a quoted string (single or double quotes).
    fn parse_quoted_string(&mut self) -> Result<String, ParseError> {
        let quote = self.bytes[self.pos];
        let start_pos = self.pos;
        self.pos += 1; // consume opening quote
        let value_start = self.pos;

        while self.pos < self.bytes.len() && self.bytes[self.pos] != quote {
            self.pos += 1;
        }

        if self.pos >= self.bytes.len() {
            return Err(ParseError {
                message: "unterminated quoted string".into(),
                position: start_pos,
            });
        }

        let value = self.input[value_start..self.pos].to_string();
        self.pos += 1; // consume closing quote
        Ok(value)
    }
}

/// Apply negation to an expression.
fn apply_negation(expr: QueryExpression) -> QueryExpression {
    match expr {
        QueryExpression::NamedTagQuery { key, value, wildcard, .. } => {
            QueryExpression::NamedTagQuery { key, value, negated: true, wildcard }
        }
        QueryExpression::NamelessTagQuery { value, wildcard, .. } => {
            QueryExpression::NamelessTagQuery { value, negated: true, wildcard }
        }
        QueryExpression::BareKeyword { value, name_auto_search, .. } => {
            QueryExpression::BareKeyword { value, negated: true, name_auto_search }
        }
        other => other, // Range and Boolean don't support negation directly
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    // -----------------------------------------------------------------------
    // proptest strategies for query round-trip
    // -----------------------------------------------------------------------

    /// Generate a valid identifier: starts with a letter, followed by alphanumeric/underscore.
    /// Excludes "tag" (case-insensitive) and "OR" to avoid special-case parsing.
    fn arb_identifier() -> impl Strategy<Value = String> {
        "[a-z][a-z0-9_]{0,7}"
            .prop_filter("must not be reserved keyword", |s| {
                !s.eq_ignore_ascii_case("tag") && !s.eq_ignore_ascii_case("or")
            })
    }

    /// Generate a simple value string (no whitespace, no special chars that break parsing).
    fn arb_simple_value() -> impl Strategy<Value = String> {
        "[a-z0-9][a-z0-9_]{0,9}"
    }

    /// Generate a wildcard value: value with `*` prefix, suffix, or both.
    fn arb_wildcard_value() -> impl Strategy<Value = String> {
        prop_oneof![
            arb_simple_value().prop_map(|v| format!("*{}", v)),
            arb_simple_value().prop_map(|v| format!("{}*", v)),
            arb_simple_value().prop_map(|v| format!("*{}*", v)),
        ]
    }

    /// Generate a value that may or may not be a wildcard.
    fn arb_value_with_wildcard() -> impl Strategy<Value = (String, bool)> {
        prop_oneof![
            arb_simple_value().prop_map(|v| (v, false)),
            arb_wildcard_value().prop_map(|v| (v, true)),
        ]
    }

    /// Generate a RangeItem.
    fn arb_range_item() -> impl Strategy<Value = RangeItem> {
        prop_oneof![
            // Exact value (start == end)
            "[0-9]{1,4}".prop_map(|v| RangeItem {
                start: v.clone(),
                end: v,
            }),
            // Range (start-end, both numeric)
            ("[0-9]{1,4}", "[0-9]{1,4}").prop_map(|(s, e)| RangeItem {
                start: s,
                end: e,
            }),
        ]
    }

    /// Generate a leaf (non-boolean) QueryExpression.
    fn arb_leaf_expression(name_auto_search: bool) -> impl Strategy<Value = QueryExpression> {
        prop_oneof![
            // NamedTagQuery
            (arb_identifier(), arb_value_with_wildcard(), any::<bool>()).prop_map(
                |(key, (value, wildcard), negated)| QueryExpression::NamedTagQuery {
                    key,
                    value,
                    negated,
                    wildcard,
                }
            ),
            // NamelessTagQuery
            (arb_value_with_wildcard(), any::<bool>()).prop_map(
                |((value, wildcard), negated)| QueryExpression::NamelessTagQuery {
                    value,
                    negated,
                    wildcard,
                }
            ),
            // BareKeyword (use identifier-safe values to avoid parse ambiguity)
            (arb_identifier(), any::<bool>()).prop_map(move |(value, negated)| {
                QueryExpression::BareKeyword {
                    value,
                    negated,
                    name_auto_search,
                }
            }),
            // RangeQuery
            (arb_identifier(), proptest::collection::vec(arb_range_item(), 1..=3)).prop_map(
                |(key, ranges)| QueryExpression::RangeQuery { key, ranges }
            ),
        ]
    }

    /// Generate a QueryExpression AST up to a given depth.
    fn arb_query_expression_inner(
        depth: u32,
        name_auto_search: bool,
    ) -> impl Strategy<Value = QueryExpression> {
        if depth == 0 {
            arb_leaf_expression(name_auto_search).boxed()
        } else {
            prop_oneof![
                4 => arb_leaf_expression(name_auto_search),
                1 => proptest::collection::vec(
                    arb_query_expression_inner(depth - 1, name_auto_search),
                    2..=3
                ).prop_map(|operands| QueryExpression::BooleanQuery {
                    operator: BoolOp::And,
                    operands,
                }),
                1 => proptest::collection::vec(
                    arb_query_expression_inner(depth - 1, name_auto_search),
                    2..=3
                ).prop_map(|operands| QueryExpression::BooleanQuery {
                    operator: BoolOp::Or,
                    operands,
                }),
            ]
            .boxed()
        }
    }

    /// Top-level generator for valid QueryExpression ASTs.
    fn arb_query_expression(name_auto_search: bool) -> impl Strategy<Value = QueryExpression> {
        arb_query_expression_inner(2, name_auto_search)
    }

    /// Normalize a QueryExpression for comparison after round-trip.
    ///
    /// The round-trip may not preserve the exact `wildcard` flag if the value
    /// doesn't actually contain `*`, or may change `name_auto_search` based on
    /// the parse call. This normalizer ensures we compare what the parser
    /// actually produces.
    fn normalize_for_roundtrip(expr: &QueryExpression) -> QueryExpression {
        match expr {
            QueryExpression::NamedTagQuery { key, value, negated, .. } => {
                QueryExpression::NamedTagQuery {
                    key: key.clone(),
                    value: value.clone(),
                    negated: *negated,
                    wildcard: value.contains('*'),
                }
            }
            QueryExpression::NamelessTagQuery { value, negated, .. } => {
                QueryExpression::NamelessTagQuery {
                    value: value.clone(),
                    negated: *negated,
                    wildcard: value.contains('*'),
                }
            }
            QueryExpression::BareKeyword { value, negated, name_auto_search } => {
                QueryExpression::BareKeyword {
                    value: value.clone(),
                    negated: *negated,
                    name_auto_search: *name_auto_search,
                }
            }
            QueryExpression::RangeQuery { key, ranges } => {
                QueryExpression::RangeQuery {
                    key: key.clone(),
                    ranges: ranges.clone(),
                }
            }
            QueryExpression::BooleanQuery { operator, operands } => {
                QueryExpression::BooleanQuery {
                    operator: operator.clone(),
                    operands: operands.iter().map(normalize_for_roundtrip).collect(),
                }
            }
        }
    }

    // Feature: tag-search-system, Property 14: Query round-trip
    // Validates: Requirements 8.3
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(200))]

        #[test]
        fn query_round_trip_parse_serialize_parse_equals_parse(
            expr in arb_query_expression(true)
        ) {
            // serialize the generated AST
            let text = serialize_query(&expr);

            // parse the serialized text
            let parsed = parse_query(&text, true);
            prop_assert!(parsed.is_ok(), "parse failed for serialized text: {:?} -> error: {:?}", text, parsed.err());
            let parsed = parsed.unwrap();

            // serialize again and parse again
            let text2 = serialize_query(&parsed);
            let parsed2 = parse_query(&text2, true);
            prop_assert!(parsed2.is_ok(), "second parse failed for: {:?} -> error: {:?}", text2, parsed2.err());
            let parsed2 = parsed2.unwrap();

            // The round-trip property: parse ∘ serialize ∘ parse = parse
            prop_assert_eq!(
                normalize_for_roundtrip(&parsed),
                normalize_for_roundtrip(&parsed2),
                "round-trip failed:\n  original AST: {:?}\n  serialized: {:?}\n  parsed: {:?}\n  re-serialized: {:?}\n  re-parsed: {:?}",
                expr, text, parsed, text2, parsed2
            );
        }

        #[test]
        fn query_round_trip_with_name_auto_search_false(
            expr in arb_query_expression(false)
        ) {
            let text = serialize_query(&expr);

            let parsed = parse_query(&text, false);
            prop_assert!(parsed.is_ok(), "parse failed for: {:?} -> error: {:?}", text, parsed.err());
            let parsed = parsed.unwrap();

            let text2 = serialize_query(&parsed);
            let parsed2 = parse_query(&text2, false);
            prop_assert!(parsed2.is_ok(), "second parse failed for: {:?} -> error: {:?}", text2, parsed2.err());
            let parsed2 = parsed2.unwrap();

            prop_assert_eq!(
                normalize_for_roundtrip(&parsed),
                normalize_for_roundtrip(&parsed2),
                "round-trip failed (nas=false):\n  serialized: {:?}\n  parsed: {:?}\n  re-serialized: {:?}\n  re-parsed: {:?}",
                text, parsed, text2, parsed2
            );
        }
    }

    // ---- parse_query tests ----

    #[test]
    fn empty_input_returns_empty_and() {
        let result = parse_query("", true).unwrap();
        assert_eq!(result, QueryExpression::BooleanQuery {
            operator: BoolOp::And,
            operands: vec![],
        });
    }

    #[test]
    fn bare_keyword() {
        let result = parse_query("hello", true).unwrap();
        assert_eq!(result, QueryExpression::BareKeyword {
            value: "hello".into(),
            negated: false,
            name_auto_search: true,
        });
    }

    #[test]
    fn bare_keyword_auto_search_off() {
        let result = parse_query("hello", false).unwrap();
        assert_eq!(result, QueryExpression::BareKeyword {
            value: "hello".into(),
            negated: false,
            name_auto_search: false,
        });
    }

    #[test]
    fn named_tag_query() {
        let result = parse_query("artist:luotianyi", true).unwrap();
        assert_eq!(result, QueryExpression::NamedTagQuery {
            key: "artist".into(),
            value: "luotianyi".into(),
            negated: false,
            wildcard: false,
        });
    }

    #[test]
    fn tag_xxx_produces_nameless() {
        let result = parse_query("tag:v4", true).unwrap();
        assert_eq!(result, QueryExpression::NamelessTagQuery {
            value: "v4".into(),
            negated: false,
            wildcard: false,
        });
    }

    #[test]
    fn negated_named_tag() {
        let result = parse_query("-artist:bad", true).unwrap();
        assert_eq!(result, QueryExpression::NamedTagQuery {
            key: "artist".into(),
            value: "bad".into(),
            negated: true,
            wildcard: false,
        });
    }

    #[test]
    fn negated_bare_keyword() {
        let result = parse_query("-hello", true).unwrap();
        assert_eq!(result, QueryExpression::BareKeyword {
            value: "hello".into(),
            negated: true,
            name_auto_search: true,
        });
    }

    #[test]
    fn negated_nameless_tag() {
        let result = parse_query("-tag:v4", true).unwrap();
        assert_eq!(result, QueryExpression::NamelessTagQuery {
            value: "v4".into(),
            negated: true,
            wildcard: false,
        });
    }

    #[test]
    fn wildcard_value() {
        let result = parse_query("name:*hello*", true).unwrap();
        assert_eq!(result, QueryExpression::NamedTagQuery {
            key: "name".into(),
            value: "*hello*".into(),
            negated: false,
            wildcard: true,
        });
    }

    #[test]
    fn and_query() {
        let result = parse_query("artist:a album:b", true).unwrap();
        assert_eq!(result, QueryExpression::BooleanQuery {
            operator: BoolOp::And,
            operands: vec![
                QueryExpression::NamedTagQuery { key: "artist".into(), value: "a".into(), negated: false, wildcard: false },
                QueryExpression::NamedTagQuery { key: "album".into(), value: "b".into(), negated: false, wildcard: false },
            ],
        });
    }

    #[test]
    fn or_query() {
        let result = parse_query("artist:a OR artist:b", true).unwrap();
        assert_eq!(result, QueryExpression::BooleanQuery {
            operator: BoolOp::Or,
            operands: vec![
                QueryExpression::NamedTagQuery { key: "artist".into(), value: "a".into(), negated: false, wildcard: false },
                QueryExpression::NamedTagQuery { key: "artist".into(), value: "b".into(), negated: false, wildcard: false },
            ],
        });
    }

    #[test]
    fn grouped_expression() {
        let result = parse_query("(artist:a OR artist:b) album:c", true).unwrap();
        assert_eq!(result, QueryExpression::BooleanQuery {
            operator: BoolOp::And,
            operands: vec![
                QueryExpression::BooleanQuery {
                    operator: BoolOp::Or,
                    operands: vec![
                        QueryExpression::NamedTagQuery { key: "artist".into(), value: "a".into(), negated: false, wildcard: false },
                        QueryExpression::NamedTagQuery { key: "artist".into(), value: "b".into(), negated: false, wildcard: false },
                    ],
                },
                QueryExpression::NamedTagQuery { key: "album".into(), value: "c".into(), negated: false, wildcard: false },
            ],
        });
    }

    #[test]
    fn range_query_single() {
        let result = parse_query("year:[2017-2024]", true).unwrap();
        assert_eq!(result, QueryExpression::RangeQuery {
            key: "year".into(),
            ranges: vec![RangeItem { start: "2017".into(), end: "2024".into() }],
        });
    }

    #[test]
    fn range_query_multi() {
        let result = parse_query("year:[2017,2019-2021]", true).unwrap();
        assert_eq!(result, QueryExpression::RangeQuery {
            key: "year".into(),
            ranges: vec![
                RangeItem { start: "2017".into(), end: "2017".into() },
                RangeItem { start: "2019".into(), end: "2021".into() },
            ],
        });
    }

    #[test]
    fn unclosed_paren_error() {
        let result = parse_query("(artist:a", true);
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(err.message.contains("parenthesis"));
    }

    #[test]
    fn unclosed_bracket_error() {
        let result = parse_query("year:[2017-2024", true);
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(err.message.contains("]"));
    }

    #[test]
    fn quoted_value() {
        let result = parse_query("name:\"hello world\"", true).unwrap();
        assert_eq!(result, QueryExpression::NamedTagQuery {
            key: "name".into(),
            value: "hello world".into(),
            negated: false,
            wildcard: false,
        });
    }

    // ---- serialize_query tests ----

    #[test]
    fn serialize_named_tag() {
        let expr = QueryExpression::NamedTagQuery {
            key: "artist".into(),
            value: "luotianyi".into(),
            negated: false,
            wildcard: false,
        };
        assert_eq!(serialize_query(&expr), "artist:luotianyi");
    }

    #[test]
    fn serialize_negated_named_tag() {
        let expr = QueryExpression::NamedTagQuery {
            key: "artist".into(),
            value: "bad".into(),
            negated: true,
            wildcard: false,
        };
        assert_eq!(serialize_query(&expr), "-artist:bad");
    }

    #[test]
    fn serialize_nameless_tag() {
        let expr = QueryExpression::NamelessTagQuery {
            value: "v4".into(),
            negated: false,
            wildcard: false,
        };
        assert_eq!(serialize_query(&expr), "tag:v4");
    }

    #[test]
    fn serialize_bare_keyword() {
        let expr = QueryExpression::BareKeyword {
            value: "hello".into(),
            negated: false,
            name_auto_search: true,
        };
        assert_eq!(serialize_query(&expr), "hello");
    }

    #[test]
    fn serialize_range() {
        let expr = QueryExpression::RangeQuery {
            key: "year".into(),
            ranges: vec![
                RangeItem { start: "2017".into(), end: "2017".into() },
                RangeItem { start: "2019".into(), end: "2021".into() },
            ],
        };
        assert_eq!(serialize_query(&expr), "year:[2017,2019-2021]");
    }

    #[test]
    fn serialize_and_query() {
        let expr = QueryExpression::BooleanQuery {
            operator: BoolOp::And,
            operands: vec![
                QueryExpression::NamedTagQuery { key: "a".into(), value: "1".into(), negated: false, wildcard: false },
                QueryExpression::NamedTagQuery { key: "b".into(), value: "2".into(), negated: false, wildcard: false },
            ],
        };
        assert_eq!(serialize_query(&expr), "a:1 b:2");
    }

    #[test]
    fn serialize_or_with_parens() {
        let expr = QueryExpression::BooleanQuery {
            operator: BoolOp::And,
            operands: vec![
                QueryExpression::BooleanQuery {
                    operator: BoolOp::Or,
                    operands: vec![
                        QueryExpression::NamedTagQuery { key: "a".into(), value: "1".into(), negated: false, wildcard: false },
                        QueryExpression::NamedTagQuery { key: "a".into(), value: "2".into(), negated: false, wildcard: false },
                    ],
                },
                QueryExpression::NamedTagQuery { key: "b".into(), value: "3".into(), negated: false, wildcard: false },
            ],
        };
        assert_eq!(serialize_query(&expr), "(a:1 OR a:2) b:3");
    }

    // ---- parse_to_chips tests ----

    #[test]
    fn chips_empty() {
        let chips = parse_to_chips("", true).unwrap();
        assert!(chips.is_empty());
    }

    #[test]
    fn chips_single_named_tag() {
        let chips = parse_to_chips("artist:luotianyi", true).unwrap();
        assert_eq!(chips.len(), 1);
        assert_eq!(chips[0].chip_type, ChipType::NamedTag);
        assert_eq!(chips[0].text, "artist:luotianyi");
    }

    #[test]
    fn chips_and_query() {
        let chips = parse_to_chips("artist:a album:b", true).unwrap();
        assert_eq!(chips.len(), 2);
        assert_eq!(chips[0].chip_type, ChipType::NamedTag);
        assert_eq!(chips[1].chip_type, ChipType::NamedTag);
    }

    #[test]
    fn chips_or_query() {
        let chips = parse_to_chips("artist:a OR artist:b", true).unwrap();
        assert_eq!(chips.len(), 3);
        assert_eq!(chips[0].chip_type, ChipType::NamedTag);
        assert_eq!(chips[1].chip_type, ChipType::OrOperator);
        assert_eq!(chips[2].chip_type, ChipType::NamedTag);
    }

    #[test]
    fn chips_negated() {
        let chips = parse_to_chips("-artist:bad", true).unwrap();
        assert_eq!(chips.len(), 1);
        assert_eq!(chips[0].chip_type, ChipType::Negation);
    }

    #[test]
    fn chips_range() {
        let chips = parse_to_chips("year:[2017-2024]", true).unwrap();
        assert_eq!(chips.len(), 1);
        assert_eq!(chips[0].chip_type, ChipType::Range);
    }

    #[test]
    fn chips_bare_keyword() {
        let chips = parse_to_chips("hello", true).unwrap();
        assert_eq!(chips.len(), 1);
        assert_eq!(chips[0].chip_type, ChipType::BareKeyword);
    }

    #[test]
    fn chips_nameless_tag() {
        let chips = parse_to_chips("tag:v4", true).unwrap();
        assert_eq!(chips.len(), 1);
        assert_eq!(chips[0].chip_type, ChipType::NamelessTag);
    }

    // -----------------------------------------------------------------------
    // Property tests for parser behavior (Task 4.5)
    // -----------------------------------------------------------------------

    // Feature: tag-search-system, Property 7: Bare keyword parsing respects name_auto_search setting
    // Validates: Requirements 5.1, 5.2, 5.3
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(200))]

        #[test]
        fn bare_keyword_respects_name_auto_search(
            keyword in "[a-z][a-z0-9]{0,9}"
                .prop_filter("must not be reserved", |s| {
                    !s.eq_ignore_ascii_case("or") && !s.eq_ignore_ascii_case("tag")
                })
        ) {
            // With name_auto_search=true
            let result_true = parse_query(&keyword, true).unwrap();
            match &result_true {
                QueryExpression::BareKeyword { value, negated, name_auto_search } => {
                    prop_assert_eq!(value, &keyword);
                    prop_assert!(!negated);
                    prop_assert!(*name_auto_search, "name_auto_search should be true");
                }
                other => prop_assert!(false, "expected BareKeyword, got {:?}", other),
            }

            // With name_auto_search=false
            let result_false = parse_query(&keyword, false).unwrap();
            match &result_false {
                QueryExpression::BareKeyword { value, negated, name_auto_search } => {
                    prop_assert_eq!(value, &keyword);
                    prop_assert!(!negated);
                    prop_assert!(!name_auto_search, "name_auto_search should be false");
                }
                other => prop_assert!(false, "expected BareKeyword, got {:?}", other),
            }
        }
    }

    // Feature: tag-search-system, Property 8: Named tag query parsing preserves key, value, and negation
    // Validates: Requirements 6.1, 6.3
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(200))]

        #[test]
        fn named_tag_query_preserves_key_value_negation(
            key in arb_identifier(),
            value in arb_simple_value(),
        ) {
            // Non-negated: key:value
            let input = format!("{}:{}", key, value);
            let result = parse_query(&input, true).unwrap();
            match &result {
                QueryExpression::NamedTagQuery { key: k, value: v, negated, wildcard } => {
                    prop_assert_eq!(k, &key);
                    prop_assert_eq!(v, &value);
                    prop_assert!(!negated);
                    prop_assert!(!wildcard);
                }
                other => prop_assert!(false, "expected NamedTagQuery for '{}', got {:?}", input, other),
            }

            // Negated: -key:value
            let neg_input = format!("-{}:{}", key, value);
            let neg_result = parse_query(&neg_input, true).unwrap();
            match &neg_result {
                QueryExpression::NamedTagQuery { key: k, value: v, negated, wildcard } => {
                    prop_assert_eq!(k, &key);
                    prop_assert_eq!(v, &value);
                    prop_assert!(*negated);
                    prop_assert!(!wildcard);
                }
                other => prop_assert!(false, "expected negated NamedTagQuery for '{}', got {:?}", neg_input, other),
            }
        }
    }

    // Feature: tag-search-system, Property 9: tag:xxx produces nameless query, -keyword produces negated bare query
    // Validates: Requirements 6.2, 6.4
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(200))]

        #[test]
        fn tag_xxx_nameless_and_neg_keyword_negated_bare(
            value in arb_simple_value(),
            keyword in "[a-z][a-z0-9]{0,9}"
                .prop_filter("must not be reserved", |s| {
                    !s.eq_ignore_ascii_case("or") && !s.eq_ignore_ascii_case("tag")
                })
        ) {
            // tag:xxx → NamelessTagQuery
            let tag_input = format!("tag:{}", value);
            let tag_result = parse_query(&tag_input, true).unwrap();
            match &tag_result {
                QueryExpression::NamelessTagQuery { value: v, negated, wildcard } => {
                    prop_assert_eq!(v, &value);
                    prop_assert!(!negated);
                    prop_assert!(!wildcard);
                }
                other => prop_assert!(false, "expected NamelessTagQuery for '{}', got {:?}", tag_input, other),
            }

            // -keyword → negated BareKeyword
            let neg_input = format!("-{}", keyword);
            let neg_result = parse_query(&neg_input, true).unwrap();
            match &neg_result {
                QueryExpression::BareKeyword { value: v, negated, name_auto_search } => {
                    prop_assert_eq!(v, &keyword);
                    prop_assert!(*negated);
                    prop_assert!(*name_auto_search);
                }
                other => prop_assert!(false, "expected negated BareKeyword for '{}', got {:?}", neg_input, other),
            }
        }
    }

    // Feature: tag-search-system, Property 10: Space-separated terms produce AND, OR-separated terms produce OR
    // Validates: Requirements 7.1, 7.2
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(200))]

        #[test]
        fn space_produces_and_or_produces_or(
            key1 in arb_identifier(),
            val1 in arb_simple_value(),
            key2 in arb_identifier(),
            val2 in arb_simple_value(),
        ) {
            // Space-separated → AND
            let and_input = format!("{}:{} {}:{}", key1, val1, key2, val2);
            let and_result = parse_query(&and_input, true).unwrap();
            match &and_result {
                QueryExpression::BooleanQuery { operator, operands } => {
                    prop_assert_eq!(operator, &BoolOp::And);
                    prop_assert_eq!(operands.len(), 2);
                }
                other => prop_assert!(false, "expected AND BooleanQuery for '{}', got {:?}", and_input, other),
            }

            // OR-separated → OR
            let or_input = format!("{}:{} OR {}:{}", key1, val1, key2, val2);
            let or_result = parse_query(&or_input, true).unwrap();
            match &or_result {
                QueryExpression::BooleanQuery { operator, operands } => {
                    prop_assert_eq!(operator, &BoolOp::Or);
                    prop_assert_eq!(operands.len(), 2);
                }
                other => prop_assert!(false, "expected OR BooleanQuery for '{}', got {:?}", or_input, other),
            }
        }
    }

    // Feature: tag-search-system, Property 11: Parenthesized expressions are parsed as grouped units
    // Validates: Requirements 7.3
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(200))]

        #[test]
        fn parenthesized_expressions_grouped(
            key_a in arb_identifier(),
            val_a in arb_simple_value(),
            key_b in arb_identifier(),
            val_b in arb_simple_value(),
            key_c in arb_identifier(),
            val_c in arb_simple_value(),
        ) {
            // (A OR B) C → AND of (OR of A, B) with C
            let input = format!("({}:{} OR {}:{}) {}:{}", key_a, val_a, key_b, val_b, key_c, val_c);
            let result = parse_query(&input, true).unwrap();
            match &result {
                QueryExpression::BooleanQuery { operator: top_op, operands: top_ops } => {
                    prop_assert_eq!(top_op, &BoolOp::And, "top-level should be AND");
                    prop_assert_eq!(top_ops.len(), 2, "should have 2 top-level operands");
                    // First operand should be OR group
                    match &top_ops[0] {
                        QueryExpression::BooleanQuery { operator: inner_op, operands: inner_ops } => {
                            prop_assert_eq!(inner_op, &BoolOp::Or, "inner should be OR");
                            prop_assert_eq!(inner_ops.len(), 2, "inner OR should have 2 operands");
                        }
                        other => prop_assert!(false, "expected inner OR BooleanQuery, got {:?}", other),
                    }
                    // Second operand should be a NamedTagQuery
                    match &top_ops[1] {
                        QueryExpression::NamedTagQuery { key, value, .. } => {
                            prop_assert_eq!(key, &key_c);
                            prop_assert_eq!(value, &val_c);
                        }
                        other => prop_assert!(false, "expected NamedTagQuery for C, got {:?}", other),
                    }
                }
                other => prop_assert!(false, "expected AND BooleanQuery for '{}', got {:?}", input, other),
            }
        }
    }

    // Feature: tag-search-system, Property 12: Range query parsing
    // Validates: Requirements 7.4
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(200))]

        #[test]
        fn range_query_parsing(
            key in arb_identifier(),
            min_val in "[0-9]{1,4}",
            max_val in "[0-9]{1,4}",
        ) {
            let input = format!("{}:[{}-{}]", key, min_val, max_val);
            let result = parse_query(&input, true).unwrap();
            match &result {
                QueryExpression::RangeQuery { key: k, ranges } => {
                    prop_assert_eq!(k, &key);
                    prop_assert_eq!(ranges.len(), 1);
                    prop_assert_eq!(&ranges[0].start, &min_val);
                    prop_assert_eq!(&ranges[0].end, &max_val);
                }
                other => prop_assert!(false, "expected RangeQuery for '{}', got {:?}", input, other),
            }
        }
    }

    // Feature: tag-search-system, Property 13: Wildcard flag is set when value contains asterisk
    // Validates: Requirements 7.5
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(200))]

        #[test]
        fn wildcard_flag_set_when_asterisk_present(
            key in arb_identifier(),
            wc_value in arb_wildcard_value(),
            plain_value in arb_simple_value(),
        ) {
            // Wildcard value → wildcard=true
            let wc_input = format!("{}:{}", key, wc_value);
            let wc_result = parse_query(&wc_input, true).unwrap();
            match &wc_result {
                QueryExpression::NamedTagQuery { wildcard, .. } => {
                    prop_assert!(*wildcard, "wildcard should be true for value '{}'", wc_value);
                }
                other => prop_assert!(false, "expected NamedTagQuery for '{}', got {:?}", wc_input, other),
            }

            // Plain value → wildcard=false
            let plain_input = format!("{}:{}", key, plain_value);
            let plain_result = parse_query(&plain_input, true).unwrap();
            match &plain_result {
                QueryExpression::NamedTagQuery { wildcard, .. } => {
                    prop_assert!(!wildcard, "wildcard should be false for value '{}'", plain_value);
                }
                other => prop_assert!(false, "expected NamedTagQuery for '{}', got {:?}", plain_input, other),
            }
        }
    }

    // Feature: tag-search-system, Property 15: Invalid queries produce errors with position
    // Validates: Requirements 8.4
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(200))]

        #[test]
        fn invalid_queries_produce_errors_with_position(
            // Generate various invalid query patterns
            variant in 0u8..5,
            key in arb_identifier(),
            val in arb_simple_value(),
        ) {
            let invalid_input = match variant {
                0 => format!("({}:{}", key, val),           // unclosed paren
                1 => format!("{}:[{}-", key, val),          // unclosed bracket
                2 => format!("{}:[]", key),                 // empty range
                3 => format!("{}:{} OR", key, val),         // trailing OR
                _ => format!("){}:{}", key, val),           // leading close paren
            };

            let result = parse_query(&invalid_input, true);
            prop_assert!(result.is_err(), "expected error for '{}', got {:?}", invalid_input, result);
            let err = result.unwrap_err();
            prop_assert!(!err.message.is_empty(), "error message should not be empty");
            prop_assert!(
                err.position <= invalid_input.len(),
                "error position {} should be <= input length {} for '{}'",
                err.position, invalid_input.len(), invalid_input
            );
        }
    }

    // Feature: tag-search-system, Property 20: Chip count matches top-level conditions
    // Validates: Requirements 10.1
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(200))]

        #[test]
        fn chip_count_matches_top_level_conditions(
            // Generate 2-4 named tag conditions joined by spaces (AND)
            terms in proptest::collection::vec(
                (arb_identifier(), arb_simple_value()),
                2..=4
            )
        ) {
            let n = terms.len();
            let input = terms.iter()
                .map(|(k, v)| format!("{}:{}", k, v))
                .collect::<Vec<_>>()
                .join(" ");

            let chips = parse_to_chips(&input, true).unwrap();
            // AND query: N conditions → N chips (no OR operator chips)
            prop_assert_eq!(
                chips.len(), n,
                "expected {} chips for AND query '{}', got {} chips: {:?}",
                n, input, chips.len(), chips
            );

            // Also test OR: N conditions → N condition chips + (N-1) OR chips
            let or_input = terms.iter()
                .map(|(k, v)| format!("{}:{}", k, v))
                .collect::<Vec<_>>()
                .join(" OR ");

            let or_chips = parse_to_chips(&or_input, true).unwrap();
            let expected_or_chips = n + (n - 1); // N conditions + (N-1) OR operators
            prop_assert_eq!(
                or_chips.len(), expected_or_chips,
                "expected {} chips for OR query '{}', got {} chips: {:?}",
                expected_or_chips, or_input, or_chips.len(), or_chips
            );

            // Verify OR operator chips are in the right positions
            for i in 0..or_chips.len() {
                if i % 2 == 1 {
                    prop_assert_eq!(
                        &or_chips[i].chip_type, &ChipType::OrOperator,
                        "chip at index {} should be OrOperator, got {:?}",
                        i, or_chips[i].chip_type
                    );
                } else {
                    prop_assert_ne!(
                        &or_chips[i].chip_type, &ChipType::OrOperator,
                        "chip at index {} should NOT be OrOperator",
                        i
                    );
                }
            }
        }
    }
}
