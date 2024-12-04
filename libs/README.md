# Lua Libs

This directory is for common libraries used by Lua scripts, NOT Rust libraries.

## Conversion Notes

### Mappings From "Global" Python Functions

#### datetimeFromUtcLocal(utc_datetime)

There is no mapping for this.  We may need to, but at this point, I've been
just ignoring it.  Need to see if this is really needed.

#### cleanNumbers(result)

There is no direct substitute for this. However, this is always used with
discrete values, and there is a higher level function called
`GetDvValueNumber(dv)` that will give you `dv.result` as a number, and this
includes clearing out junk characters before the conversion.

#### dataConversion(datetime, linkText, Result, id, category, sequence, abstract=True, gender=None)

This is replaced by `ReplaceLinkPlaceholders(linkTemplate, codeReference, document, discreteValue, medication)`
But generally, you won't use this as it's called by the normal link building
functions (GetCodeLink, etc.)

#### CodeCount(codes)

`GetAccountCodesInDictionary(codes)`

#### abstractValue(abstraction_name, link_text, calculation, sequence=0, category=None, abstract=False)

Look at the suffix of link_text, it will be one of these two:

1. `" '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"`
2. `": [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"`

If it's the first one (without the ABSTRACTVALUE):

```lua
GetAbstractionLink {
    code = abstraction_name,
    text = link_text,           -- ommit the suffix when passing this
    seq = sequence,
    target = category,
    predicate = calculation
}
```

If it's the second one (with the ABSTRACTVALUE) 

```lua
GetAbstractionValueLink {
    code = abstraction_name,
    text = link_text,           -- ommit the suffix when passing this
    seq = sequence,
    target = category,
    predicate = calculation
}
```

#### dvValue(dv_name, link_text, calculation, sequence, category, abstract)

```lua
GetDiscreteValueLink {
    discreteValueName = dv_name,
    text = link_text,           -- ommit the suffix ": [DISCRETEVALUE] (Result Date: [RESULTDATE])"
    seq = sequence,
    target = category,
    predicate = calculation
}
```

#### dvValueMulti(dvDic, DV1, linkText, value, sign, sequence, category, abstract, needed)

```lua
GetDiscreteValueLinks {
    discreteValueNames = DV1,
    text = linkText,           -- ommit the suffix ": [DISCRETEVALUE] (Result Date: [RESULTDATE])"
    seq = sequence,
    target = category,
    predicate = function(dv)
        GetDvValueNumber(dv) > value  -- if sign is gt. adjust operator according to sign function
    end
    maxPerValue = needed
}
```

#### compareValuesMulti(dvDic, DV1, value, value1, linkText, sign, sign1, sequence=0, category=None, abstract=False, needed=2)

(Not yet encountered/implemented)

#### codeValue(code_name, link_text, sequence, category, abstract)

```lua
GetCodeLink {
    code = code_name,
    text = link_text,           -- ommit the suffix ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"
    seq = sequence,
    target = category
}
```

#### multiCodeValue(code_list, link_text, sequence, category, abstract)

```lua
GetCodeLink {
    codes = code_list,
    text = link_text,           -- ommit the suffix ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"
    seq = sequence,
    target = category
}
```

(The "multi" in this case only refers to it looking for one of many codes,
not for it making multiple links)

#### mprefixCodeValue(prefix, link_text, sequence, category, abstract)

```lua
GetCodePrefixLink {
    prefix = prefix,
    text = link_text,           -- ommit the suffix ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"
    seq = sequence,
    target = category
}
```

#### medValue(med_name, link_text, sequence, category, abstract)

```lua
GetMedicationLink {
    cat = med_name,
    text = link_text,           -- ommit the suffix ": [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])"
    seq = sequence,
    target = category
}
```

#### updateLinkText(value, replacement_text)

Just inline these...

```lua
value.link_text = replacement_text ... value.link_text
```

### documentLink(DocumentType, LinkText, sequence, category, abstract)

```lua
GetDocumentLink {
    documentType = DocumentType,
    text = linkText,            -- ommit the suffix " ([DOCUMENTTYPE], [DOCUMENTDATE])"
}
```

### Notes For Script Specific Functions

Check the `discrete_values.lua` file for a number of useful functions for
dealing with getting discrete values in different ways.  Add as needed.

There are similar libraries for codes, etc.
