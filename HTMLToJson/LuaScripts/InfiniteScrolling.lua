function main(splash)
    local scroll_delay = 1
    local previous_height = -1
    local number_of_scrolls = 0
    local maximal_number_of_scrolls = 99

    local scroll_to = splash:jsfunc("window.scrollTo")
    local get_body_height = splash:jsfunc(
        "function() {return document.body.scrollHeight;}"
    )
    local get_inner_height = splash:jsfunc(
        "function() {return window.innerHeight;}"
    )
    local get_body_scroll_top = splash:jsfunc(
        "function() {return document.body.scrollTop;}"
    )
    assert(splash:go(splash.args.url))
    splash:wait(splash.args.wait)

    while true do
        local body_height = get_body_height()
        local current = get_inner_height() - get_body_scroll_top()
        scroll_to(0, body_height)
        number_of_scrolls = number_of_scrolls + 1
        if number_of_scrolls == maximal_number_of_scrolls then
            break
        end
        splash:wait(scroll_delay)
        local new_body_height = get_body_height()
        if new_body_height - body_height <= 0 then
            break
        end
    end        
    return splash:html()
end