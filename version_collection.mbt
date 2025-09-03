// Copyright (c) HashiCorp, Inc.
// Copyright (c) 2025 International Digital Economy Academy
// SPDX-License-Identifier: MPL-2.0

///|
/// Collection is a type alias for Array[Version] that provides sorting functionality
pub typealias Array[Version] as Collection

///|
/// Sort versions in place
pub fn collection_sort(versions : Array[Version]) -> Unit {
  versions.sort_by(fn(a, b) { a.compare(b) })
}

///|
/// Sort versions in place using a custom comparison function
pub fn collection_sort_by_fn(
  versions : Array[Version],
  compare : (Version, Version) -> Int,
) -> Unit {
  versions.sort_by(compare)
}

///|
/// Create a new sorted collection from an array of version strings
pub fn collection_from_strings(
  version_strings : Array[String],
) -> Array[Version] raise VersionError {
  let collection : Array[Version] = []
  for version_str in version_strings {
    let version = Version::new(version_str)
    collection.push(version)
  }
  collection_sort(collection)
  collection
}

///|
/// Check if the collection is sorted
pub fn collection_is_sorted(versions : Array[Version]) -> Bool {
  for i = 1; i < versions.length(); i = i + 1 {
    if versions[i - 1].greater_than(versions[i]) {
      return false
    }
  }
  true
}
