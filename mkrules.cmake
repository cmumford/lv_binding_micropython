
find_package(Python3 REQUIRED COMPONENTS Interpreter)
find_program(AWK awk mawk gawk)

set(LV_BINDINGS_DIR ${MICROPY_DIR}/lib/lv_bindings)

# Common function for creating LV bindings

function(lv_bindings)
    set(_options)
    set(_one_value_args OUTPUT)
    set(_multi_value_args INPUT DEPENDS PP_OPTIONS GEN_OPTIONS FILTER)
    cmake_parse_arguments(
        PARSE_ARGV 0 LV
        "${_options}"
        "${_one_value_args}"
        "${_multi_value_args}"
    )

    set(LV_PP ${LV_OUTPUT}.pp)
    set(LV_MPY_METADATA ${LV_OUTPUT}.json)

    add_custom_command(
        OUTPUT 
            ${LV_PP}
        COMMAND
        ${CMAKE_C_COMPILER} -E -DPYCPARSER ${LV_PP_OPTIONS} "${LV_CFLAGS}" -I ${LV_BINDINGS_DIR}/pycparser/utils/fake_libc_include ${MICROPY_CPP_FLAGS} ${LV_INPUT} > ${LV_PP}
        DEPENDS
            ${LV_INPUT}
            ${LV_DEPENDS}
            ${LV_BINDINGS_DIR}/pycparser/utils/fake_libc_include
        IMPLICIT_DEPENDS
            C ${LV_INPUT}
        VERBATIM
        COMMAND_EXPAND_LISTS
    )

    if (DEFINED LV_FILTER)

        set(LV_PP_FILTERED ${LV_PP}.filtered)
        set(LV_AWK_CONDITION)
        foreach(_f ${LV_FILTER})
            string(APPEND LV_AWK_CONDITION "\$3!~\"${_f}\" && ")
        endforeach()
        string(APPEND LV_AWK_COMMAND "\$1==\"#\"{p=(${LV_AWK_CONDITION} 1)} p{print}")

        # message("AWK COMMAND: ${LV_AWK_COMMAND}")

        add_custom_command(
            OUTPUT
                ${LV_PP_FILTERED}
            COMMAND
                ${AWK} ${LV_AWK_COMMAND} ${LV_PP} > ${LV_PP_FILTERED}
            DEPENDS
                ${LV_PP}
            VERBATIM
            COMMAND_EXPAND_LISTS
        )
    else()
        set(LV_PP_FILTERED ${LV_PP})
    endif()

    add_custom_command(
        OUTPUT
            ${LV_OUTPUT}
        COMMAND
            ${Python3_EXECUTABLE} ${LV_BINDINGS_DIR}/gen/gen_mpy.py ${LV_GEN_OPTIONS} -MD ${LV_MPY_METADATA} -E ${LV_PP_FILTERED} ${LV_INPUT} > ${LV_OUTPUT} || (rm -f ${LV_OUTPUT} && /bin/false)
        DEPENDS
            ${LV_BINDINGS_DIR}/gen/gen_mpy.py
            ${LV_PP_FILTERED}
        COMMAND_EXPAND_LISTS
    )

endfunction()

# Definitions for specific bindings

set(LVGL_DIR ${LV_BINDINGS_DIR}/lvgl)
set(LV_PNG_DIR ${LV_BINDINGS_DIR}/driver/png/lodepng)

set(LV_MP ${CMAKE_BINARY_DIR}/lv_mp.c)
set(LV_PNG ${CMAKE_BINARY_DIR}/lv_png.c)
set(LV_PNG_C ${CMAKE_BINARY_DIR}/lv_png_c.c)
set(LV_ESPIDF ${CMAKE_BINARY_DIR}/lv_espidf.c)

# Function for creating all specific bindings

function(all_lv_bindings)

    # LVGL bindings

    file(GLOB_RECURSE LVGL_HEADERS ${LVGL_DIR}/src/*.h ${LV_BINDINGS_DIR}/lv_conf.h)
    lv_bindings(
        OUTPUT
            ${LV_MP}
        INPUT
            ${LVGL_DIR}/lvgl.h
        DEPENDS
            ${LVGL_HEADERS}
        GEN_OPTIONS
            -M lvgl -MP lv
    )
        
    # LODEPNG bindings

    file(GLOB_RECURSE LV_PNG_HEADERS ${LV_PNG_DIR}/*.h)
    configure_file(${LV_PNG_DIR}/lodepng.cpp ${LV_PNG_C} COPYONLY)
    idf_build_set_property(COMPILE_DEFINITIONS "${LV_PNG_PP_OPTIONS}" APPEND)
    lv_bindings(
        OUTPUT
            ${LV_PNG}
        INPUT
            ${LV_PNG_DIR}/lodepng.h
        DEPENDS
            ${LV_PNG_HEADERS}
        PP_OPTIONS
            -DLODEPNG_NO_COMPILE_ENCODER -DLODEPNG_NO_COMPILE_DISK -DLODEPNG_NO_COMPILE_ALLOCATORS
        GEN_OPTIONS
            -M lodepng
    )

    # ESPIDF bindings

    file(GLOB_RECURSE LV_ESPIDF_HEADERS ${IDF_PATH}/components/*.h ${LV_BINDINGS_DIR}/driver/esp32/*.h)
    lv_bindings(
        OUTPUT
            ${LV_ESPIDF}
        INPUT
            ${LV_BINDINGS_DIR}/driver/esp32/espidf.h
        DEPENDS
            ${LV_ESPIDF_HEADERS}
        PP_OPTIONS
            -DPYCPARSER
        GEN_OPTIONS
             -M espidf
        FILTER
            i2s_ll.h
            i2s_hal.h
            esp_intr_alloc.h
            soc/spi_periph.h
            rom/ets_sys.h
            soc/sens_struct.h
            soc/rtc.h
            driver/periph_ctrl.h
            include/esp_private
    )

endfunction()

# Add includes to CMake component

set(LV_INCLUDE
    ${LV_BINDINGS_DIR}
    ${LV_PNG_DIR}
)

# Add sources to CMake component

set(LV_SRC
    ${LV_MP}

    ${LV_BINDINGS_DIR}/driver/esp32/espidf.c
    ${LV_BINDINGS_DIR}/driver/esp32/modrtch.c
    ${LV_BINDINGS_DIR}/driver/esp32/sh2lib.c

    ${LV_PNG}
    ${LV_PNG_C}
    ${LV_BINDINGS_DIR}/driver/png/mp_lodepng.c

    ${LV_ESPIDF}
)


