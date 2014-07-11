cmake_minimum_required(VERSION 2.8)

if(NOT RUSTC)
set(RUSTC rustc)
endif()

function(ensure_project_target)
  if(NOT TARGET "prj-${PROJECT_NAME}")
    add_custom_target("prj-${PROJECT_NAME}" ALL)
  endif()
endfunction()

function(rust_target libfile type)
  set(libfile_abs ${CMAKE_CURRENT_SOURCE_DIR}/${libfile})
  execute_process(COMMAND ${RUSTC} --crate-name ${libfile_abs}
                  OUTPUT_VARIABLE crate_name
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(${type} STREQUAL "lib")
    execute_process(
      COMMAND ${RUSTC} --crate-file-name ${libfile_abs}
      OUTPUT_VARIABLE crate_filenames)
  else()
    execute_process(
      COMMAND ${RUSTC} --crate-type bin --crate-file-name ${libfile_abs}
      OUTPUT_VARIABLE crate_filenames)
  endif()
  string(REPLACE ${CMAKE_CURRENT_SOURCE_DIR}/ ${CMAKE_CURRENT_BINARY_DIR}/ libfile_out ${libfile_abs})
  execute_process(COMMAND ${RUSTC} --no-analysis --dep-info ${libfile_out}.depinfo ${libfile_abs}
                  OUTPUT_QUIET ERROR_QUIET)
  file(READ ${libfile_out}.depinfo depinfo)
  file(REMOVE ${libfile_out}.depinfo)
  string(REGEX MATCHALL "[^\n]+" lib_outputs ${crate_filenames})
  string(REGEX MATCHALL "[^\n:]+: [^\n]+" depinfo_lines ${depinfo})

  list(GET depinfo_lines 0 depinfo_line)
  string(REGEX REPLACE "^[^:]+: " "" depinfo ${depinfo_line})
  string(REGEX MATCHALL "[^ ]+" dep_files ${depinfo})

  get_filename_component(libfile_out_dir ${libfile_out} DIRECTORY)
  get_filename_component(libfile_out_name ${libfile_out} NAME)
  configure_file(${libfile_abs} ${libfile_out_dir}/.${libfile_out_name}.cmake-trigger)

  if("${type}" STREQUAL "test")
    separate_arguments(RUSTFLAGS)
    add_custom_command(
      OUTPUT ${crate_name}-test
      COMMAND ${RUSTC} ${RUSTFLAGS} --test -o ${crate_name}-test ${libfile_abs}
      DEPENDS ${dep_files})
    if(NOT TARGET check-${crate_name})
      add_custom_target(
        check-${crate_name}
        COMMAND ./${crate_name}-test
        DEPENDS ${crate_name}-test)
    endif()
    if(NOT TARGET check)
      add_custom_target(check)
    endif()
    add_dependencies(check check-${crate_name})
  else()
    string(TOUPPER ${PROJECT_NAME} upper_project_name)
    string(REPLACE "-" "_" prop_name ${upper_project_name})
    set_property(GLOBAL PROPERTY ${prop_name}_LIBRARY ${CMAKE_CURRENT_BINARY_DIR})
    separate_arguments(RUSTFLAGS)
    add_custom_command(
      OUTPUT ${lib_outputs}
      COMMAND ${RUSTC} ${RUSTFLAGS} ${libfile_abs}
      DEPENDS ${dep_files})
    ensure_project_target()
    add_custom_target(${crate_name}_${type} DEPENDS ${lib_outputs})
    add_dependencies("prj-${PROJECT_NAME}" ${crate_name}_${type})
  endif()
endfunction(rust_target)

function(rust_binary libfile)
  rust_target(${libfile} "bin")
endfunction(rust_binary)

function(rust_library libfile)
  rust_target(${libfile} "lib")
endfunction(rust_library)

function(rust_test libfile)
  rust_target(${libfile} "test")
endfunction(rust_test)

function(add_rust_dependencies name)
  ensure_project_target()
  add_dependencies("prj-${PROJECT_NAME}" prj-${name})
  string(TOUPPER ${name} name_upper)
  string(REPLACE "-" "_" prop_name ${name_upper})
  get_property(lib_dir GLOBAL PROPERTY ${prop_name}_LIBRARY)
  set(RUSTFLAGS "${RUSTFLAGS} -L ${lib_dir}" PARENT_SCOPE)
endfunction(add_rust_dependencies)
