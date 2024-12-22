---@diagnostic disable-next-line:name-style-check
return function(Account)
    ---------------------------------------------------------------------------------------------
    --- headers.lua - A library of functions for creating alert headers
    ---------------------------------------------------------------------------------------------
    local links_lib = require "libs.common.basic_links" (Account)
    local codes_lib = require "libs.common.codes" (Account)
    local module = {}

    --- @class header_builder
    --- @field name string
    --- @field sequence_counter integer
    --- @field links CdiAlertLink[]
    --- @field make_header_builder (fun (name: string, seq: integer): header_builder)
    --- @field build (fun (self: header_builder, require_links: boolean): CdiAlertLink)
    --- @field add_link (fun (self: header_builder, link: CdiAlertLink?))
    --- @field add_links (fun (self: header_builder, lnks: CdiAlertLink[]))
    --- @field add_text_link (fun (self: header_builder, text: string, validated: boolean?))
    --- @field add_document_link (fun (self: header_builder, document_type: string, description: string))
    --- @field add_code_link (fun (self: header_builder, code: string, description: string))
    --- @field add_code_links (fun (self: header_builder, codes: string[], description: string))
    --- @field add_code_prefix_link (fun (self: header_builder, prefix: string, description: string))
    --- @field add_abstraction_link (fun (self: header_builder, abstraction: string, description: string))
    --- @field add_abstraction_link_with_value (fun (self: header_builder, abstraction: string, description: string))
    --- @field add_discrete_value_link (fun (self: header_builder, dv_name: string, description: string, predicate: (fun (dv: DiscreteValue, num: number?): boolean)?))
    --- @field add_discrete_value_one_of_link (fun (self: header_builder, dv_names: string[], description: string, predicate: (fun (dv: DiscreteValue, num: number?): boolean)?))
    --- @field add_discrete_value_links (fun (self: header_builder, dv_name: string, description: string, max: number, predicate: (fun (dv: DiscreteValue, num: number?): boolean)?))
    --- @field add_discrete_value_many_links (fun (self: header_builder, dv_names: string[], description: string, max_per_value: number, predicate: (fun (dv: DiscreteValue, num: number?): boolean)?))
    --- @field add_medication_link (fun (self: header_builder, cat: string, description: string, predicate: (fun (med: Medication): boolean)?))
    --- @field add_medication_links (fun (self: header_builder, cats: string[], description: string, predicate: (fun (med: Medication): boolean)?))

    local header_builder_meta = {
        __index = {
            --- @param self header_builder
            --- @param require_links boolean
            --- @return CdiAlertLink?
            build = function(self, require_links)
                if require_links and #self.links == 0 then
                    return nil
                end
                local header =
                    links_lib.make_header_link(self.name)
                header.links = self.links
                return header
            end,

            --- @param self header_builder
            --- @param link CdiAlertLink?
            add_link = function(self, link)
                if link and not link.sequence then
                    link.sequence = self.sequence_counter
                    self.sequence_counter = self.sequence_counter + 1
                end
                table.insert(self.links, link)
            end,

            --- @param self header_builder
            --- @param lnks CdiAlertLink[]
            add_links = function(self, lnks)
                for _, link in ipairs(lnks) do
                    link.sequence = self.sequence_counter
                    self.sequence_counter = self.sequence_counter + 1
                    self:add_link(link)
                end
            end,

            --- @param self header_builder
            --- @param text string
            --- @param validated boolean?
            add_text_link = function(self, text, validated)
                local link = links_lib.make_header_link(text, validated)
                if link then
                    link.sequence = self.sequence_counter
                    self.sequence_counter = self.sequence_counter + 1
                    self:add_link(link)
                end
            end,

            --- @param self header_builder
            --- @param document_type string
            --- @param description string
            add_document_link = function(self, document_type, description)
                local link = links_lib.get_document_link { documentType = document_type, text = description }
                if link then
                    link.sequence = self.sequence_counter
                    self.sequence_counter = self.sequence_counter + 1
                    self:add_link(link)
                end
            end,

            --- @param self header_builder
            --- @param code string
            --- @param description string
            add_code_link = function(self, code, description)
                local link = links_lib.get_code_link { code = code, text = description }
                if link then
                    link.sequence = self.sequence_counter
                    self.sequence_counter = self.sequence_counter + 1
                    self:add_link(link)
                end
            end,

            --- @param self header_builder
            --- @param codes string[];
            --- @param description string
            add_code_links = function(self, codes, description)
                for _, code in ipairs(codes) do
                    local link = links_lib.get_code_link { code = code, text = description }
                    if link then
                        link.sequence = self.sequence_counter
                        self.sequence_counter = self.sequence_counter + 1
                        self:add_link(link)
                    end
                end
            end,

            --- @param self header_builder
            --- @param prefix string
            --- @param description string
            add_code_prefix_link = function(self, prefix, description)
                local link = codes_lib.get_code_prefix_link { prefix = prefix, text = description }
                if link then
                    link.sequence = self.sequence_counter
                    self.sequence_counter = self.sequence_counter + 1
                    self:add_link(link)
                end
            end,

            --- @param self header_builder
            --- @param abstraction string
            --- @param description string
            add_abstraction_link = function(self, abstraction, description)
                local link = links_lib.get_abstraction_link { code = abstraction, text = description }
                if link then
                    link.sequence = self.sequence_counter
                    self.sequence_counter = self.sequence_counter + 1
                    self:add_link(link)
                end
            end,

            --- @param self header_builder
            --- @param abstraction string
            --- @param description string
            add_abstraction_link_with_value = function(self, abstraction, description)
                local link = links_lib.get_abstraction_value_link { code = abstraction, text = description }
                if link then
                    link.sequence = self.sequence_counter
                    self.sequence_counter = self.sequence_counter + 1
                    self:add_link(link)
                end
            end,

            --- @param self header_builder
            --- @param dv_name string
            --- @param description string
            --- @param predicate (fun (dv: DiscreteValue, num: number): boolean)?
            add_discrete_value_link = function(self, dv_name, description, predicate)
                local link = links_lib.get_discrete_value_link { discreteValueName = dv_name, text = description, predicate = predicate }
                if link then
                    link.sequence = self.sequence_counter
                    self.sequence_counter = self.sequence_counter + 1
                    self:add_link(link)
                end
            end,

            --- @param self header_builder
            --- @param dv_names string[]
            --- @param description string
            --- @param predicate (fun (dv: DiscreteValue, num: number): boolean)?
            add_discrete_value_one_of_link = function(self, dv_names, description, predicate)
                local link = links_lib.get_discrete_value_link { discreteValueNames = dv_names, text = description, predicate = predicate }
                if link then
                    link.sequence = self.sequence_counter
                    self.sequence_counter = self.sequence_counter + 1
                    self:add_link(link)
                end
            end,

            --- @param self header_builder
            --- @param dv_name string
            --- @param description string
            --- @param max number
            --- @param predicate (fun (dv: DiscreteValue, num: number): boolean)?
            add_discrete_value_links = function(self, dv_name, description, max, predicate)
                local lnks = links_lib.get_discrete_value_links {
                    discreteValueName = dv_name,
                    text = description,
                    predicate = predicate,
                    max_per_value = max
                }

                for _, link in ipairs(lnks) do
                    link.sequence = self.sequence_counter
                    self.sequence_counter = self.sequence_counter + 1
                    self:add_link(link)
                end
            end,

            --- @param self header_builder
            --- @param dv_names string[]
            --- @param description string
            --- @param max_per_value number
            --- @param predicate (fun (dv: DiscreteValue, num: number): boolean)?
            add_discrete_value_many_links = function(self, dv_names, description, max_per_value, predicate)
                local lnks = links_lib.get_discrete_value_links {
                    discreteValueNames = dv_names,
                    text = description,
                    predicate = predicate,
                    max_per_value = max_per_value
                }

                for _, link in ipairs(lnks) do
                    link.sequence = self.sequence_counter
                    self.sequence_counter = self.sequence_counter + 1
                    self:add_link(link)
                end
            end,

            --- @param self header_builder
            --- @param cat string
            --- @param description string
            --- @param predicate (fun (med: Medication): boolean)?
            add_medication_link = function(self, cat, description, predicate)
                local link = links_lib.get_medication_link { cat = cat, text = description, predicate = predicate }
                if link then
                    link.sequence = self.sequence_counter
                    self.sequence_counter = self.sequence_counter + 1
                    self:add_link(link)
                end
            end,

            --- @param self header_builder
            --- @param cats string[]
            --- @param description string
            --- @param predicate (fun (med: Medication): boolean)?
            add_medication_links = function(self, cats, description, predicate)
                local lnks = links_lib.get_medication_links { cats = cats, text = description, predicate = predicate }
                for _, link in ipairs(lnks) do
                    link.sequence = self.sequence_counter
                    self.sequence_counter = self.sequence_counter + 1
                    self:add_link(link)
                end
            end,
        }
    }

    --- @param name string
    --- @param seq integer
    --- @return header_builder
    function module.make_header_builder(name, seq)
        -- @type header_builder
        local h = {}
        h.name = name
        h.links = {}
        h.sequence = seq
        h.sequence_counter = 1

        setmetatable(h, header_builder_meta)

        return h
    end

    return module
end
