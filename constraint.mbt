// Copyright (c) HashiCorp, Inc.
// Copyright (c) 2025 International Digital Economy Academy
// SPDX-License-Identifier: MPL-2.0

///|
/// Operator types for version constraints
pub enum Operator {
  Equal
  NotEqual
  GreaterThan
  LessThan
  GreaterThanEqual
  LessThanEqual
  Pessimistic
} derive(Eq, Show)

///|
/// Constraint represents a single constraint for a version, such as ">= 1.0"
pub struct Constraint {
  op : Operator
  version : Version
  original : String
} derive(Eq, Show)

///|
/// Constraints is an array of constraints
pub typealias Array[Constraint] as Constraints

///|
/// Create a new constraint from a string like ">= 1.0", "< 2.0", etc.
pub fn Constraint::new(
  constraint_str : String,
) -> Constraint raise VersionError {
  let trimmed = constraint_str.trim_space().to_string()

  // Check for empty constraint
  if trimmed.length() == 0 {
    raise VersionError(
      "malformed constraint: cannot parse empty constraint string",
    )
  }

  // Parse operator and version
  let (op, version_str) = if trimmed.strip_prefix(">=") is Some(remaining) {
    (Operator::GreaterThanEqual, remaining)
  } else if trimmed.strip_prefix("<=") is Some(remaining) {
    (Operator::LessThanEqual, remaining)
  } else if trimmed.strip_prefix("!=") is Some(remaining) {
    (Operator::NotEqual, remaining)
  } else if trimmed.strip_prefix("~>") is Some(remaining) {
    (Operator::Pessimistic, remaining)
  } else if trimmed.strip_prefix(">") is Some(remaining) {
    (Operator::GreaterThan, remaining)
  } else if trimmed.strip_prefix("<") is Some(remaining) {
    (Operator::LessThan, remaining)
  } else if trimmed.strip_prefix("=") is Some(remaining) {
    (Operator::Equal, remaining)
  } else {
    (Operator::Equal, trimmed)
  }
  let cleaned_version_str = version_str.trim_space().to_string()
  if cleaned_version_str.length() == 0 {
    raise VersionError(
      "malformed constraint '\{constraint_str}': missing version after operator",
    )
  }
  let version = Version::new(cleaned_version_str) catch {
    e => raise VersionError("malformed constraint '\{constraint_str}': \{e}")
  }
  { op, version, original: constraint_str }
}

///|
/// Create constraints from a comma-separated string like ">= 1.0, < 2.0"
pub fn constraints_new(
  constraints_str : String,
) -> Array[Constraint] raise VersionError {
  let parts = constraints_str.split(",")
  let constraints : Array[Constraint] = []
  for part in parts {
    let constraint = Constraint::new(part.trim_space().to_string())
    constraints.push(constraint)
  }
  constraints
}

///|
/// MustConstraints is a helper that wraps a call to constraints_new
/// and panics if error is non-nil
pub fn constraints_must(constraints_str : String) -> Array[Constraint] {
  constraints_new(constraints_str) catch {
    e => abort("Constraint parse error: \{e}")
  }
}

///|
/// Check if a version satisfies this constraint
pub fn Constraint::check(self : Constraint, version : Version) -> Bool {
  match self.op {
    Operator::Equal => version.equal(self.version)
    Operator::NotEqual => !version.equal(self.version)
    Operator::GreaterThan => check_greater_than(version, self.version)
    Operator::LessThan => check_less_than(version, self.version)
    Operator::GreaterThanEqual =>
      check_greater_than_equal(version, self.version)
    Operator::LessThanEqual => check_less_than_equal(version, self.version)
    Operator::Pessimistic => check_pessimistic(version, self.version)
  }
}

///|
/// Check if a version satisfies all constraints
pub fn constraints_check(
  constraints : Array[Constraint],
  version : Version,
) -> Bool {
  for constraint in constraints {
    if !constraint.check(version) {
      return false
    }
  }
  true
}

///|
/// Helper function for greater than constraint with prerelease handling
fn check_greater_than(version : Version, constraint_version : Version) -> Bool {
  if !prerelease_check(version, constraint_version) {
    return false
  }
  version.compare(constraint_version) > 0
}

///|
/// Helper function for less than constraint with prerelease handling
fn check_less_than(version : Version, constraint_version : Version) -> Bool {
  if !prerelease_check(version, constraint_version) {
    return false
  }
  version.compare(constraint_version) < 0
}

///|
/// Helper function for greater than or equal constraint with prerelease handling
fn check_greater_than_equal(
  version : Version,
  constraint_version : Version,
) -> Bool {
  if !prerelease_check(version, constraint_version) {
    return false
  }
  version.compare(constraint_version) >= 0
}

///|
/// Helper function for less than or equal constraint with prerelease handling
fn check_less_than_equal(
  version : Version,
  constraint_version : Version,
) -> Bool {
  if !prerelease_check(version, constraint_version) {
    return false
  }
  version.compare(constraint_version) <= 0
}

///|
/// Helper function for prerelease constraint checking (matches Go's prereleaseCheck)
/// Note: For pessimistic constraints, we use relaxed segment checking
fn prerelease_check_relaxed(
  version : Version,
  constraint_version : Version,
  is_pessimistic : Bool,
) -> Bool {
  let v_pre = version.prerelease() != ""
  let c_pre = constraint_version.prerelease() != ""
  match (c_pre, v_pre) {
    (true, true) =>
      if is_pessimistic {
        // For pessimistic constraints with prerelease, we only check that both have prerelease
        // The actual version bounds will be checked by the pessimistic logic
        true
      } else {
        // A constraint with a pre-release can only match a pre-release version
        // with the same base segments.
        version.equal_segments(constraint_version)
      }
    (false, true) =>
      // A constraint without a pre-release can only match a version without a
      // pre-release.
      false
    (true, false) =>
      // OK, except with the pessimistic operator (will be handled by caller)
      true
    (false, false) =>
      // OK
      true
  }
}

///|
/// Helper function for prerelease constraint checking (matches Go's prereleaseCheck)
fn prerelease_check(version : Version, constraint_version : Version) -> Bool {
  prerelease_check_relaxed(version, constraint_version, false)
}

///|
/// Helper function for pessimistic constraint (~>)
/// This allows patch-level changes if a patch version is specified,
/// or minor-level changes if no patch version is specified.
fn check_pessimistic(version : Version, constraint_version : Version) -> Bool {
  // Using a pessimistic constraint with a pre-release, restricts versions to pre-releases
  if !prerelease_check_relaxed(version, constraint_version, true) ||
    (constraint_version.prerelease() != "" && version.prerelease() == "") {
    return false
  }

  // If the version being checked is naturally less than the constraint, then there
  // is no way for the version to be valid against the constraint
  if version.less_than(constraint_version) {
    return false
  }
  let v_segments = version.segments64()
  let c_segments = constraint_version.segments64()

  // We'll use this more than once, so grab the length now so it's a little cleaner
  // to write the later checks
  let cs = c_segments.length()

  // If the version being checked has less specificity than the constraint, then there
  // is no way for the version to be valid against the constraint
  if cs > v_segments.length() {
    return false
  }

  // For pessimistic constraints, we need to check that:
  // 1. All segments except the last one in the constraint must match exactly
  // 2. The last segment in the constraint must be <= the corresponding segment in version
  // 
  // For ~> 1.2, constraint_version.si = 2, so we check:
  // - segment 0 (major) must be equal
  // - segment 1 (minor) can be >= but we need to ensure version doesn't exceed next major level

  // Check all segments from 0 to constraint_version.si-1 for exact match except the last one
  for i = 0; i < constraint_version.si - 1; i = i + 1 {
    if v_segments[i] != c_segments[i] {
      return false
    }
  }

  // For the last specified segment in constraint, version must be >= constraint
  if constraint_version.si > 0 &&
    c_segments[constraint_version.si - 1] >
    v_segments[constraint_version.si - 1] {
    return false
  }

  // Additional check: ensure version doesn't exceed the "next" version level
  // Based on Go's test cases, the semantics seem to be based on the precision specified:
  // ~> 1.0 means >= 1.0.0 and < 2.0.0 (segment 1 is 0, so increment major)
  // ~> 1.2 means >= 1.2.0 and < 1.3.0 (segment 1 is non-zero, so increment minor)
  // ~> 1.2.3 means >= 1.2.3 and < 1.3.0 (segment 2 is non-zero, but still increment minor)
  if constraint_version.si >= 1 {
    let next_version_segments = c_segments.copy()
    // Determine which level to increment based on the constraint's precision
    let increment_index = if c_segments.length() >= 2 && c_segments[1] != 0L {
      1 // If minor version is specified (non-zero), increment minor
    } else {
      0 // If only major is specified (minor is 0), increment major
    }
    next_version_segments[increment_index] = next_version_segments[increment_index] +
      1L
    // Set all segments after increment_index to 0
    for i = increment_index + 1; i < next_version_segments.length(); i = i + 1 {
      next_version_segments[i] = 0L
    }

    // Check if version >= next_version (if so, reject)
    // Use standard version comparison: returns -1, 0, 1 for <, =, >
    let mut compare_result = 0
    for i = 0
        i < next_version_segments.length() && i < v_segments.length()
        i = i + 1 {
      if v_segments[i] < next_version_segments[i] {
        compare_result = -1
        break
      } else if v_segments[i] > next_version_segments[i] {
        compare_result = 1
        break
      }
      // If equal, continue to next segment
    }

    // If all compared segments are equal, check array lengths
    if compare_result == 0 {
      if v_segments.length() < next_version_segments.length() {
        compare_result = -1
      } else if v_segments.length() > next_version_segments.length() {
        compare_result = 1
      }
      // If equal lengths and all segments equal, compare_result remains 0
    }

    // Reject if version >= next_version
    if compare_result >= 0 {
      return false
    }
  }

  // If nothing has rejected the version by now, it's valid
  true
}

///|
/// Convert constraint to string
pub fn Constraint::to_string(self : Constraint) -> String {
  self.original
}

///|
/// Convert constraints to string
pub fn constraints_to_string(constraints : Array[Constraint]) -> String {
  let parts : Array[String] = []
  for constraint in constraints {
    parts.push(constraint.to_string())
  }
  parts.join(", ")
}

///|
/// Check if constraint has prerelease
pub fn Constraint::has_prerelease(self : Constraint) -> Bool {
  self.version.prerelease().length() > 0
}

///|
/// Check if two constraints are equal
pub fn Constraint::equals(self : Constraint, other : Constraint) -> Bool {
  self.op == other.op && self.version.equal(other.version)
}

///|
/// Check if two constraint arrays are equal
pub fn constraints_equal(
  left : Array[Constraint],
  right : Array[Constraint],
) -> Bool {
  if left.length() != right.length() {
    return false
  }

  // Create sorted copies
  let left_sorted : Array[Constraint] = []
  let right_sorted : Array[Constraint] = []
  for c in left {
    left_sorted.push(c)
  }
  for c in right {
    right_sorted.push(c)
  }

  // Sort by operator first, then by version
  left_sorted.sort_by(fn(a, b) {
    let op_cmp = compare_operators(a.op, b.op)
    if op_cmp != 0 {
      op_cmp
    } else {
      a.version.compare(b.version)
    }
  })
  right_sorted.sort_by(fn(a, b) {
    let op_cmp = compare_operators(a.op, b.op)
    if op_cmp != 0 {
      op_cmp
    } else {
      a.version.compare(b.version)
    }
  })

  // Compare sorted arrays
  for i = 0; i < left_sorted.length(); i = i + 1 {
    if !left_sorted[i].equals(right_sorted[i]) {
      return false
    }
  }
  true
}

///|
/// Helper function to compare operators for sorting
fn compare_operators(a : Operator, b : Operator) -> Int {
  let a_val = match a {
    Operator::Equal => 0
    Operator::NotEqual => 1
    Operator::GreaterThan => 2
    Operator::LessThan => 3
    Operator::GreaterThanEqual => 4
    Operator::LessThanEqual => 5
    Operator::Pessimistic => 6
  }
  let b_val = match b {
    Operator::Equal => 0
    Operator::NotEqual => 1
    Operator::GreaterThan => 2
    Operator::LessThan => 3
    Operator::GreaterThanEqual => 4
    Operator::LessThanEqual => 5
    Operator::Pessimistic => 6
  }
  if a_val < b_val {
    -1
  } else if a_val > b_val {
    1
  } else {
    0
  }
}

///|
/// Create a constraint that accepts any version >= the given version
pub fn constraint_at_least(
  version_str : String,
) -> Constraint raise VersionError {
  Constraint::new(">= \{version_str}")
}

///|
/// Create a constraint that accepts any version < the given version
pub fn constraint_below(version_str : String) -> Constraint raise VersionError {
  Constraint::new("< \{version_str}")
}

///|
/// Create a constraint for an exact version match
pub fn constraint_exactly(
  version_str : String,
) -> Constraint raise VersionError {
  Constraint::new("= \{version_str}")
}

///|
/// Create a pessimistic constraint (~>) for the given version
pub fn constraint_pessimistic(
  version_str : String,
) -> Constraint raise VersionError {
  Constraint::new("~> \{version_str}")
}

///|
/// Create a range constraint ">=min, <max"
pub fn constraint_range(
  min_version : String,
  max_version : String,
) -> Array[Constraint] raise VersionError {
  constraints_new(">= \{min_version}, < \{max_version}")
}

///|
/// Check if constraints allow any version (i.e., are not overly restrictive)
pub fn constraints_allow_any(constraints : Array[Constraint]) -> Bool {
  // Simple heuristic: if there are no constraints, any version is allowed
  constraints.length() == 0
}

///|
/// Get the strictest lower bound from a set of constraints
pub fn constraints_min_version(constraints : Array[Constraint]) -> Version? {
  let mut min_version : Version? = None
  for constraint in constraints {
    match constraint.op {
      Operator::GreaterThan | Operator::GreaterThanEqual =>
        match min_version {
          None => min_version = Some(constraint.version)
          Some(current_min) =>
            if constraint.version.greater_than(current_min) {
              min_version = Some(constraint.version)
            }
        }
      _ => continue
    }
  }
  min_version
}

///|
/// Get the strictest upper bound from a set of constraints
pub fn constraints_max_version(constraints : Array[Constraint]) -> Version? {
  let mut max_version : Version? = None
  for constraint in constraints {
    match constraint.op {
      Operator::LessThan | Operator::LessThanEqual =>
        match max_version {
          None => max_version = Some(constraint.version)
          Some(current_max) =>
            if constraint.version.less_than(current_max) {
              max_version = Some(constraint.version)
            }
        }
      _ => continue
    }
  }
  max_version
}
