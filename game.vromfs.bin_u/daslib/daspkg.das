options gen2
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
    _pkg_meta.tags |> push(tag)
}

def package_tags(tags : array<string>) {
    _pkg_meta.tags |> push_clone_from(tags)
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



struct ReleaseSpec {
    name : string                       
    main_script : string                
    wasm_main_script : string           
    include_globs : array<string>       
    include_if_missing_globs : array<string> 
    exclude_globs : array<string>       
    forced_modules : array<string>      
    native_dlls : array<string>         
    bundle_id : string                  
    emcc_args : array<string>           
    embed_paths : array<string>         
    web_shell : string                  
    wasm_build_command : string         
    wasm_archives : array<string>       
    requires_jit : bool                 
    include_symbols : bool              
    external_files : array<string>      
}

var _release_spec : ReleaseSpec

def release_name(name : string) {
    _release_spec.name = name
}

def release_main(script : string) {
    _release_spec.main_script = script
}




def release_requires_jit() {
    _release_spec.requires_jit = true
}




def release_include_symbols() {
    _release_spec.include_symbols = true
}


def release_wasm_main(script : string) {
    _release_spec.wasm_main_script = script
}

def release_include(pattern : string) {
    _release_spec.include_globs |> push(pattern)
}


def release_include_if_missing(pattern : string) {
    _release_spec.include_if_missing_globs |> push(pattern)
}


def release_include_from(source, dest : string) {
    _release_spec.external_files |> push("{source}@{dest}")
}

def release_include_from(source : string) {
    
    
    _release_spec.external_files |> push("{source}@")
}

def release_exclude(pattern : string) {
    _release_spec.exclude_globs |> push(pattern)
}

def release_shared_module(name : string) {
    _release_spec.forced_modules |> push(name)
}


def release_include_dll(name : string) {
    _release_spec.native_dlls |> push(name)
}

def release_bundle_id(id : string) {
    _release_spec.bundle_id = id
}


def release_emcc_arg(arg : string) {
    _release_spec.emcc_args |> push(arg)
}


def release_embed_file(src, dst : string) {
    _release_spec.embed_paths |> push("{src}@{dst}")
}




def release_web_shell(path : string) {
    _release_spec.web_shell = path
}


def release_wasm_build(command : string) {
    _release_spec.wasm_build_command = command
}


def release_wasm_archive(path : string) {
    _release_spec.wasm_archives |> push(path)
}

