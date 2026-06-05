options gen2
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options no_global_variables = false
options indenting = 4
options strict_smart_pointers = true

module daspkg shared public










struct PackageMeta {
    pkg_name : string
    author : string
    description : string
    source : string
    license : string
    tags : array<string>
    min_sdk : string
}



var _pkg_meta : PackageMeta

def package_name(name : string) {
    _pkg_meta.pkg_name = name
}

def package_author(author : string) {
    _pkg_meta.author = author
}

def package_description(desc : string) {
    _pkg_meta.description = desc
}

def package_source(url : string) {
    _pkg_meta.source = url
}

def package_license(license : string) {
    _pkg_meta.license = license
}

def package_tag(tag : string) {
    _pkg_meta.tags |> push_clone(tag)
}

def package_tags(tags : array<string>) {
    _pkg_meta.tags |> reserve(length(_pkg_meta.tags) + length(tags))
    for (t in tags) {
        _pkg_meta.tags |> push_clone(t)
    }
}

def package_min_sdk(version : string) {
    _pkg_meta.min_sdk = version
}



enum DownloadKind {
    unset
    tag
    branch
    redirect
}

var _download_kind : DownloadKind = DownloadKind.unset
var _download_ref : string
var _download_source : string

def download_tag(tag : string) {
    _download_kind = DownloadKind.tag
    _download_ref = tag
}

def download_branch(branch : string) {
    _download_kind = DownloadKind.branch
    _download_ref = branch
}

def download_redirect(source, ref : string) {
    _download_kind = DownloadKind.redirect
    _download_source = source
    _download_ref = ref
}



struct Dependency {
    source : string
    version_constraint : string
}

var _dependencies : array<Dependency>

def require_package(source : string; version_constraint : string = "") {
    _dependencies |> emplace(Dependency(source = source, version_constraint = version_constraint))
}



enum BuildKind {
    no_build
    cmake
    custom
}

var _build_kind : BuildKind = BuildKind.no_build
var _build_command : string

def cmake_build() {
    _build_kind = BuildKind.cmake
}

def no_build() {
    _build_kind = BuildKind.no_build
}

def custom_build(command : string) {
    _build_kind = BuildKind.custom
    _build_command = command
}

