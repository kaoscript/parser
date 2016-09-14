#[test]
func foo() {
}

#[cfg(target_os = "darwin")]
func darwin_only() {
}

#[cfg(target_os="linux")]
func linux_only() {
}

#[cfg(any(foo, bar))]
func needs_foo_or_bar() {
}

#[cfg(all(unix))]
func on_unix() {
}

#[cfg(not(foo))]
func needs_not_foo() {
}