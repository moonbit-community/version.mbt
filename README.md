# MoonBit Version Library

A MoonBit library for parsing, comparing, and handling semantic versions.
This is a port of the [hashicorp/go-version](https://github.com/hashicorp/go-version) library.

## Usage

### Version Parsing and Comparison

```moonbit
test "basic version usage" {
  let v1 = Version::new("1.2.3") catch { _ => abort("Failed to parse v1") }
  let v2 = Version::new("1.5.0+metadata") catch { _ => abort("Failed to parse v2") }
  
  // Basic comparison
  if v1.less_than(v2) {
    println("\{v1} is less than \{v2}")
  }
  
  // Get version components
  let segments = v1.segments()  // [1, 2, 3] 
  let prerelease = v1.prerelease()  // ""
  let metadata = v1.metadata()  // ""
}
```

### Version Constraints

```moonbit
test "version constraints" {
  let version = Version::new("1.5.0") catch { _ => abort("Failed to parse version") }
  
  // Single constraint
  let constraint = Constraint::new(">= 1.0.0") catch { _ => abort("Failed to parse constraint") }
  if constraint.check(version) {
    println("Version satisfies constraint")
  }
  
  // Multiple constraints
  let constraints = constraints_new(">= 1.0.0, < 2.0.0") catch { _ => abort("Failed to parse constraints") }
  if constraints_check(constraints, version) {
    println("Version satisfies all constraints")
  }
}
```

### Version Collection Sorting

```moonbit
test "version sorting" {
  let version_strings = ["1.4.0", "1.2.0", "1.10.0", "1.4.1"]
  let sorted_versions = collection_from_strings(version_strings) catch { _ => abort("Failed to create collection") }
  
  // Versions are now sorted: 1.2.0, 1.4.0, 1.4.1, 1.10.0
  for version in sorted_versions {
    println(version.to_string())
  }
}
```

### New Utility Functions

```moonbit
test "version utilities" {
  let version = Version::new("1.2.3-alpha") catch { _ => abort("Failed to parse") }
  
  // Version stability and components
  println("Is stable: \{version.is_stable()}")        // false (has prerelease)
  println("Major: \{version.major()}")                // 1
  println("Minor: \{version.minor()}")                // 2
  println("Patch: \{version.patch()}")                // 3
  
  // Version increments
  let next_major = version.increment_major() catch { _ => abort("Failed") }   // 2.0.0
  let next_minor = version.increment_minor() catch { _ => abort("Failed") }   // 1.3.0  
  let next_patch = version.increment_patch() catch { _ => abort("Failed") }   // 1.2.4
  
  // Constraint utilities
  let at_least_1_0 = constraint_at_least("1.0.0") catch { _ => abort("Failed") }
  let below_2_0 = constraint_below("2.0.0") catch { _ => abort("Failed") }
  let range = constraint_range("1.0.0", "2.0.0") catch { _ => abort("Failed") }
  
  // Constraint analysis
  let constraints = [at_least_1_0, below_2_0]
  match constraints_min_version(constraints) {
    Some(min) => println("Min version: \{min.to_string()}")  // 1.0.0
    None => println("No minimum bound")
  }
}
```

## Supported Features

- **Version Parsing**: Supports semver-compliant version strings with metadata and prerelease information
- **Version Comparison**: Full comparison support (equal, greater than, less than, etc.)
- **Version Constraints**: Support for operators `=`, `!=`, `>`, `<`, `>=`, `<=`, `~>`
- **Version Sorting**: Built-in sorting for version collections
- **Metadata and Prerelease**: Full support for version metadata and prerelease identifiers
- **Performance Optimizations**: Fast path parsing for simple numeric versions like "1.2.3"
- **Large Number Support**: Handles versions with Int64-sized segments (up to 9,223,372,036,854,775,807)
- **Utility Functions**: Convenient helpers for version stability checks, component access, and version increments
- **Constraint Utilities**: Helper functions for creating and analyzing constraint sets
- **Enhanced Error Handling**: Descriptive error messages for easier debugging

## API Reference

### Version

- `Version::new(version_string)` - Parse a version string
- `Version::new_semver(version_string)` - Parse with strict semver rules  
- `compare(other)` - Compare two versions (-1, 0, 1)
- `equal(other)`, `greater_than(other)`, `less_than(other)` - Boolean comparisons
- `segments()` - Get version segments as Array[Int]
- `prerelease()` - Get prerelease identifier
- `metadata()` - Get build metadata
- `core()` - Get core version (major.minor.patch only)

#### New Utility Functions
- `is_stable()` - Check if version is stable (no prerelease)
- `is_prerelease()` - Check if version is prerelease
- `major()`, `minor()`, `patch()` - Get individual version components
- `increment_major()`, `increment_minor()`, `increment_patch()` - Create incremented versions

### Constraint

- `Constraint::new(constraint_string)` - Parse constraint like ">= 1.0.0"
- `check(version)` - Check if version satisfies constraint

#### Constraint Utility Functions
- `constraint_at_least(version)` - Create ">= version" constraint
- `constraint_below(version)` - Create "< version" constraint
- `constraint_exactly(version)` - Create "= version" constraint
- `constraint_pessimistic(version)` - Create "~> version" constraint
- `constraint_range(min, max)` - Create ">= min, < max" range constraint
- `constraints_min_version(constraints)` - Find minimum bound from constraints
- `constraints_max_version(constraints)` - Find maximum bound from constraints
- `constraints_allow_any(constraints)` - Check if constraints are empty/permissive

### Collection  

- `collection_from_strings(version_strings)` - Create sorted collection from strings
- `collection_sort()` - Sort versions in place
- `collection_is_sorted()` - Check if collection is sorted

## Performance Notes

This MoonBit implementation includes several optimizations for common use cases:

- **Fast path parsing**: Simple numeric versions like "1.2.3" use an optimized parsing path
- **Efficient character validation**: Character code operations instead of string operations where possible
- **Optimized comparison**: Quick equality checks before detailed comparison logic
- **Edge case handling**: Robust handling of large numbers up to Int64 maximum value

## Examples

See `cmd/example/main.mbt` for a comprehensive demo of all library features.

## License

MPL-2.0 (same as original Go library)
