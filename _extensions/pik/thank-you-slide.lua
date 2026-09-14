-- Renders a closing slide with an author list on the left and a
-- "Thank you! / Questions?" panel on the right.
--
-- Usage in a .qmd:
--
--   thank-you-slide:
--     picture-dir: author-profile-pics    (optional; this is the default)
--     authors:
--       - id: jane
--         name: Jane Doe
--         description: Lead Researcher, PIK
--         email: jane.doe@pik-potsdam.de
--         picture: photos/jane-2024.jpg    (optional; overrides picture-dir/id.jpg)
--
-- `id` is a short, stable, space-free identifier used only to look up
-- the author's picture (<picture-dir>/<id>.jpg); it stays the same
-- even if `name` later gains a title or a middle name. Set `picture`
-- on an author to point at a specific file instead.
--
--   ## {#thank-you-slide}
--
--   ::: {.thank-you-slide}
--   Anything placed here (text, images, lists, ...) is rendered
--   underneath the author cards, on the left-hand side.
--   :::
--
-- The heading with id "thank-you-slide" is what makes Quarto open a
-- new top-level slide; the fenced div is where the slide's content
-- is filled in (it must not be wrapped in its own <section>, or it
-- would be nested as a vertical sub-slide of whichever heading
-- precedes it). Optional `heading`/`subheading` attributes on the
-- div override the "Thank you!" / "Questions?" text, e.g.
-- `::: {.thank-you-slide heading="Bye!" subheading="Get in touch"}`.
--
-- Author pictures are looked up at <picture-dir>/<id>.jpg (relative
-- to the rendered presentation); a dummy silhouette is shown if no
-- picture is found for a given author.

local function escape_html(s)
  s = s:gsub('&', '&amp;')
  s = s:gsub('<', '&lt;')
  s = s:gsub('>', '&gt;')
  s = s:gsub('"', '&quot;')
  return s
end

local function url_encode_path(s)
  return s:gsub(' ', '%%20')
end

local function stringify_or_default(value, default)
  if value == nil then
    return default
  end
  local s = pandoc.utils.stringify(value)
  if s == '' then
    return default
  end
  return s
end

local function render_author(author, picture_dir)
  local name = stringify_or_default(author.name, '')
  local id = stringify_or_default(author.id, name)
  local description = stringify_or_default(author.description, nil)
  local email = stringify_or_default(author.email, nil)
  local picture = stringify_or_default(author.picture, picture_dir .. '/' .. id .. '.jpg')

  local pic_src = url_encode_path(picture)

  local html = {}
  table.insert(html, '<div class="author-card">')
  table.insert(html, string.format(
    '<img class="author-pic" src="%s" onerror="this.onerror=null;this.classList.add(\'default-avatar\');" alt="%s">',
    escape_html(pic_src), escape_html(name)
  ))
  table.insert(html, string.format('<p class="author-name">%s</p>', escape_html(name)))
  if description then
    table.insert(html, string.format('<p class="author-description">%s</p>', escape_html(description)))
  end
  if email then
    table.insert(html, string.format(
      '<p class="author-email"><a href="mailto:%s">%s</a></p>',
      escape_html(email), escape_html(email)
    ))
  end
  table.insert(html, '</div>')

  return table.concat(html)
end

return {
  Pandoc = function(doc)
    local config = doc.meta['thank-you-slide']
    local authors = (config and config.authors) or {}
    local picture_dir = stringify_or_default(config and config['picture-dir'], 'author-profile-pics')

    local author_cards = {}
    for _, author in ipairs(authors) do
      table.insert(author_cards, render_author(author, picture_dir))
    end

    local new_blocks = {}
    for _, block in ipairs(doc.blocks) do
      if block.t == 'Header' and block.identifier == 'thank-you-slide' then
        -- Suppress the deck-wide footer on this slide, same as the
        -- title slide does via title-slide-attributes: data-footer.
        block.attributes['data-footer'] = 'false'
        table.insert(new_blocks, block)
      elseif block.t == 'Div' and block.classes:includes('thank-you-slide') then
        local heading = stringify_or_default(block.attributes['heading'], 'Thank you!')
        local subheading = stringify_or_default(block.attributes['subheading'], 'Questions?')

        table.insert(new_blocks, pandoc.RawBlock('html', table.concat({
          '<div class="thank-you-authors-panel">',
          '<div class="thank-you-authors">', table.concat(author_cards), '</div>',
          '<div class="thank-you-extra">'
        })))
        for _, extra_block in ipairs(block.content) do
          table.insert(new_blocks, extra_block)
        end
        table.insert(new_blocks, pandoc.RawBlock('html', table.concat({
          '</div>', -- .thank-you-extra
          '</div>', -- .thank-you-authors-panel
          '<div class="thank-you-panel">',
          '<div class="logo-pik"></div>',
          '<div class="logo-leibniz"></div>',
          string.format('<p class="thank-you-message">%s<br>%s</p>', escape_html(heading), escape_html(subheading)),
          '</div>'
        })))
      else
        table.insert(new_blocks, block)
      end
    end

    doc.blocks = new_blocks
    return doc
  end
}
