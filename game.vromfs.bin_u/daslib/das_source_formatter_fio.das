options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true

module das_source_formatter_fio shared private

require fio
require strings
require daslib/defer
require daslib/das_source_formatter


def public format_file(file_name : string const) {
    var unformatted : string = ""
    var formatted : string = ""
    fopen(file_name, "rb") <| $(fr) {
        if (fr == null) {
            to_log(LOG_ERROR, "cannot open '{file_name}'\n")
        } else {
            fmap(fr) <| $(data) {
                unformatted = string(data)
                formatted = format_source(data)
            }
        }
    }

    if (!empty(formatted) && formatted != unformatted) {
        fopen(file_name, "wb") <| $(fw) {
            if (fw == null) {
                to_log(LOG_ERROR, "cannot open '{file_name} for write'\n")
            } else {
                fw |> fprint(formatted)
            }
        }
    }
}



def public format_files(file_names : array<string>&) {
    for (fname in file_names) {
        format_file(fname)
    }
}














































