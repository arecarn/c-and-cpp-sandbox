function(addGersmiFormatTargets)
    set(options)
    set(oneValueArgs)
    set(multiValueArgs FILES)
    cmake_parse_arguments(
        ARGS
        "${options}"
        "${oneValueArgs}"
        "${multiValueArgs}"
        ${ARGN}
    )

    # Adding clang-format check and formatter if found
    find_program(GERSEMI "gersemi")
    if(GERSEMI)
        add_custom_target(
            format_cmake
            COMMAND ${GERSEMI} -i ${ARGS_FILES}
            COMMENT "Auto formatting of all CMake source files"
        )
    endif()
endfunction()
