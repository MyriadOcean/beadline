#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();

    // Suppress verbose sea_orm / sqlx logging that floods Android logcat.
    // setup_default_user_utils() installs a logger, so we set the max level
    // to Info to filter out Debug/Trace messages from sea_orm internals.
    log::set_max_level(log::LevelFilter::Info);
}
