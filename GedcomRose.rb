require 'gedcom'
require 'prawn'
require 'pry'

# Document Contants
@size = 600
@center = @size / 2
@gens = 5
@width = (@size / (2 * (@gens + 1)))
@fontsize = 6
@people = Array.new(@gens)

# Initialize a PDF Object
@doc = Prawn::Document.new(:page_size => [@size, @size],
                           :margin => 0)
@font = @doc.font("Perpetua.ttf")
@doc.font_size(@fontsize)

# Draw the background chart
0.upto(@gens-1) do | gen |
  #@doc.stroke_axis
  @doc.stroke_circle [@center,@center], (gen+1)*@width
  segs = 2**(gen+1)
  angleInc = 2*3.1415 / segs
  1.upto(segs) do | seg |
    xstart = @center + Math.sin(angleInc*seg)*(gen)*(@width)
    xend = @center + Math.sin(angleInc*seg)*(gen+1)*(@width)
    ystart = @center + Math.cos(angleInc*seg)*(gen)*(@width)
    yend = @center + Math.cos(angleInc*seg)*(gen+1)*(@width)
    @doc.line( [xstart, ystart], [xend, yend] )
    @doc.stroke
  end
end

# Utility function to print a name in a given generation position
# Both generation and index are zero indexed
def printIndividual (individual, gen, position)
  name_data=individual.names()[0]
  name = name_data.given.first + " " + name_data.surname.first
#  print name, "  "
  if (individual.birth && individual.birth()[0].date_record)
    birth_year = individual.birth()[0].date_record[0].date_value[0][-4..-1]
  else
    birth_year = ""
  end
  if (individual.death && individual.death()[0].date_record)
    #print individual.death()[0]
    death_year = individual.death()[0].date_record[0].date_value[0][-4..-1]
  else
    death_year = ""
  end
#  print birth_year, " - ", death_year, "\n"
  lifespan = birth_year + " - " + death_year + "\n"
  # Hack to auto-adjust font size
  #if (gen < 3)
  #  @doc.font_size(@fontsize+2)
  #elsif (gen < 4)
  #  @doc.font_size(@fontsize)
  #else
  #  @doc.font_size(@fontsize-2)
  #end
  # Rotation amount = 360 (float) divided by
  # number of segements for this generation times current position
  angleInc = 360.0/(2**(gen+1))
  angle = (angleInc*position)
  # Rotation defaults to counter clockwise so invert
  # Add half a segment rotation to center the text in the cell
  @doc.rotate( -(angle+angleInc/2), :origin => [@center, @center]) do
    # Offset the text by half the text width to center in cell
    # And "up" from the rotated origin by width times current generation
    #  plus half a width to center in cell
    textHeight = @font.height()
    textWidth = @doc.width_of(name)
    @doc.draw_text(name, :at=>[@center-(textWidth/2),@center+(gen+0.5)*@width])
    textWidth = @doc.width_of(lifespan)
    @doc.draw_text(lifespan, :at=>[@center-(textWidth/2),@center+(gen+0.5)*@width-textHeight])
  end
end

# Recursive function to walk backwards from an individual
# Both generation and index are zero indexed
# In this case, save the individual into an array rather than printing immediately
def walkTree (individual, gen, position)
  #printIndividual(individual, gen, position)
  if !@people[gen]
    @people[gen] = Array.new(2**(gen+1))
  end
    @people[gen][position] = individual
  if (gen > @gens)
    return
  end
  if (individual.parents_family)
    if (individual.parents_family[0].husband())
      walkTree(individual.parents_family[0].husband(), gen+1, position*2)
    end
  end
  if (individual.parents_family)
    if (individual.parents_family[0].wife())
      walkTree(individual.parents_family[0].wife(), gen+1, position*2+1)
    end
  end
end

# Open the gedcom file to get data
g = Gedcom.file("6gen.ged", "r")
t = g.transmissions[0]
ilist = t.individual_record
mark = t.find(:individual, "I9770")
heidi = t.find(:individual, "I13761")
print mark.names()[0].given.first
print heidi.names()[0].given.first

# Gather individuals into array
walkTree(mark, 0, 0)
walkTree(heidi, 0, 1)

# For each generation, find the longest name and calculate the maximum font that will fit in the cell.
last_font_size=99
0.upto(@gens-1) do | gen |
  maxWidth = 0
  maxPos = 0
  0.upto(2**(gen+1)-1) do | pos |
    name_data=@people[gen][pos].names()[0]
    name = name_data.given.first + " " + name_data.surname.first
    textWidth = @doc.width_of(name)
    if (textWidth > maxWidth)
      maxWidth = textWidth
      maxPos = pos
    end
  end
  name_data=@people[gen][maxPos].names()[0]
  name = name_data.given.first + " " + name_data.surname.first
  print "Largest Name in gen #{gen} is "+name+"\n"
  fontSize = 1
  fits = true
  # Keep trying bigger fonts till one doesn't fit
  while (fits)
    @doc.font_size(fontSize)
    text_width = @doc.width_of(name)
    allowedWidth = 0
    if (gen == 0)
      #special case for Gen 0
      allowedWidth = 1.25*@width
    else
      angleInc = (2*3.1415 / (2**(gen+1)))
      allowedWidth = Math.sin(angleInc)*(gen+0.5)*(@width)
    end
    if (text_width > allowedWidth)
      print "#{text_width} is greater than #{allowedWidth}\n"
      fontSize = fontSize-1
      fits = false
    else
      fontSize = fontSize+1
    end
  end
  # Don't allow fonts to get bigger.  It looks weird
  if (fontSize > last_font_size)
    fontSize = last_font_size
  end
  last_font_size = fontSize
  print "Font for gen #{gen} is #{fontSize}\n"
  #Actually add names to chart
  @doc.font_size(fontSize)
  0.upto(2**(gen+1)-1) do | pos |
    printIndividual(@people[gen][pos], gen, pos)
  end
end

# Render the prepared @document
@doc.render_file("Test2.pdf")

# vim: set expandtab ts=2 sw=2 :
