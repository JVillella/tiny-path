require 'matrix'
require 'optparse'
require 'chunky_png'
# require 'byebug'

Point = Col = Vec = Vector # alias

EPSILON = 0.0001
INVERTED_PI = 1.0 / Math::PI; TWO_PI = 2 * Math::PI
MAX_DEPTH = 2

class Numeric
  def clamp(min=0, max=1)
    self < min ? min : self > max ? max : self
  end
end

class Ray
  attr_accessor :org, :dir
  def initialize(org, dir)
    @org, @dir = org, dir
  end
  def hit(t)
    @org + @dir * t
  end
end

class Camera
  attr_reader :eye, :focal, :view_dist, :up
  def initialize(eye, focal, view_dist, up)
    @eye, @focal, @view_dist, @up = eye, focal, view_dist, up
  end
  def calc_orthonormal_basis
    @w = (@eye - @focal).normalize # right-hand coordinate system
    @u = @up.cross_product(@w).normalize
    @v = @w.cross_product(@u) # already normalized
  end
  def spawn_ray(x, y)
    dir = @u * x + @v * y - @w * @view_dist
    Ray.new(@eye, dir.normalize)
  end  
end

class Mat
  attr_accessor :col
  attr_reader :emiss
  def initialize(col=WHITE)
    @col, @emiss = col, BLACK
  end
end

class Diff < Mat
  def f(wi, wo, normal)
    @col * INVERTED_PI
  end
  def sample_f(normal, wo)
    wi  = oriented_hemi_dir(Random.rand, Random.rand, normal, 0.0)
    pdf = normal.inner_product(wi) * INVERTED_PI
    [wi, pdf]
  end
end

class Spec < Mat
  def f(wi, wo, normal)
    @col
  end
  def sample_f(normal, wo)
    wi = -1 * wo + normal * 2 * normal.inner_product(wo)
    pdf = normal.inner_product(wi)
    [wi.normalize, pdf]
  end
end

class Emit < Diff
  attr_accessor :emiss
  def initialize(emiss=WHITE)
    super(emiss)
    @emiss = emiss
  end
end

class Sphere
  attr_accessor :pos, :rad, :mat, :inv_rad
  def initialize(pos, rad, mat)
    @pos, @rad, @mat = pos, rad, mat
    @inv_rad = 1.0 / @rad
  end
  def intersect(ray) # TODO: Refactor
    op = pos - ray.org
    b = op.inner_product(ray.dir)
    deter = b * b - op.inner_product(op) + @rad * @rad
    return Float::INFINITY if deter < 0

    deter = Math.sqrt(deter)
    if (t = b - deter) > EPSILON; return [t, compute_normal(ray, t)]; end
    if (t = b + deter) > EPSILON; return [t, compute_normal(ray, t)]; end
    Float::INFINITY # No hit
  end
  def compute_normal(ray, t)
    normal = (ray.hit(t) - @pos) * @inv_rad
    normal.normalize
  end
end

def sample_hemi(u1, u2, exp)
  z = (1 - u1) ** (1.0 / (exp + 1))
  phi = TWO_PI * u2 # azimuth
  theta = Math.sqrt([0.0, 1.0 - z*z].max) # polar
  Vec[theta * Math.cos(phi), theta * Math.sin(phi), z]
end

def oriented_hemi_dir(u1, u2, normal, exp)
  p = sample_hemi(u1, u2, exp) # random point on hemisphere
  w = normal # create orthonormal basis around normal
  v = Vector[0.00319, 1.0, 0.0078].cross_product(w).normalize # jittered up
  u = v.cross_product(w).normalize
  (u * p[0] + v * p[1] + w * p[2]).normalize # linear projection of hemi dir
end

def orient_normal(normal, wo) # ensure normal is pointing on side of wo
  normal.inner_product(wo) < 0 ? normal * -1 : normal
end

def mult_col(a, b)
  Col[a[0]*b[0], a[1]*b[1], a[2]*b[2]]
end

def gamma(x)
  (x.clamp**(1/2.2) * 255 + 0.5).floor
end

def intersect_spheres(ray)
  t = Float::INFINITY; hit_sphere = nil; normal = nil
  SPHERES.each do |sphere|
    dist, norm = sphere.intersect(ray)
    if dist < t
      t = dist
      hit_sphere = sphere
      normal = norm
    end
  end
  [t, hit_sphere, normal]
end

def radiance(ray, depth=0)
  return BLACK if depth > MAX_DEPTH
  t, sphere, normal = intersect_spheres(ray)
  return BLACK if t.infinite? # No intersection

  wo = ray.dir * -1 # outgoing (towards camera)
  normal = orient_normal(normal, wo)
  wi, pdf = sphere.mat.sample_f(normal, wo)
  f = sphere.mat.f(wi, wo, normal)

  result = mult_col(f, radiance(Ray.new(ray.hit(t), wi), depth + 1)) * wi.inner_product(normal) / pdf
  result + sphere.mat.emiss
end

def render(width, height, spp)
  CAMERA.calc_orthonormal_basis
  spp_inv = 1.0 / spp
  image_data = Array.new(height) { Array.new(width, BLACK) }

  inv_pixel_count = 1.0 / (width * height)
  i = 0
  for y in 0..(height - 1)
    for x in 0..(width - 1)
      pixel = Col[0,0,0]
      for s in 0..(spp - 1)
        sx = (x + Random.rand) - (width  * 0.5)
        sy = (y + Random.rand) - (height * 0.5)
        pixel += radiance(CAMERA.spawn_ray(sx, sy)) * spp_inv
      end
      image_data[y][x] = pixel
      print_progress(i, width * height)
      i += 1
    end

    save_if_progressive(y, image_data)
  end
  image_data
end

def save_if_progressive(y, image_data)
  if PROGRESSIVE_SAVING && (y % 40 == 0) # save every 40 lines
    save_image(image_data, FILENAME) # saving row
  end
end

def print_progress(current_pixel, pixel_count)
  if (current_pixel % (pixel_count / 100)) == 0
    percent = (current_pixel / pixel_count.to_f * 100).round(2)
    puts "%3i%% complete" % percent
  end
end

def save_image(image_data, filename)
  height = image_data.length
  width = image_data[0].length
  png = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::BLACK)
  for y in 0..(height - 1)
    for x in 0..(width - 1)
      p = image_data[y][x]
      png[x, y] = ChunkyPNG::Color.rgba(gamma(p[0]), gamma(p[1]), gamma(p[2]), 255)
    end
  end
  png.save(filename, :interlace => true)
end

# Create scene
RED = Col[1,0,0]; GREEN = Col[0,1,0]; BLUE = Col[0,0,1]; WHITE = Col[1,1,1]; BLACK = Col[0,0,0]
D = 520 # Sphere displacement
R = 500 # Sphere radius
SPHERES = [
  Sphere.new(Vec[ 0,-D, 0], R, Emit.new(Col[1,0.9,0.7]*0.8)), # Top
  Sphere.new(Vec[ 0, 0, D], R, Diff.new(WHITE)), # Front
  Sphere.new(Vec[ 0, 0,-D], R, Diff.new(WHITE)), # Back
  Sphere.new(Vec[ 0, D, 0], R, Diff.new(WHITE)), # Bottom
  Sphere.new(Vec[-D, 0, 0], R, Diff.new(GREEN)), # Left
  Sphere.new(Vec[ D, 0, 0], R, Diff.new(RED)),   # Right
  Sphere.new(Vec[-6, 0,20], 6, Diff.new(BLUE)),  # Center-left
  Sphere.new(Vec[ 8, 0,20], 8, Spec.new(WHITE))  # Center-right
]
CAMERA = Camera.new(Vec[0,0,-20], Vec[0,0,0], 400, Vec[0,1,0])

# Command line switches
args = { w: 512, h: 512, spp: 8, filename: 'output.png', prog_save: true }
OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.on("-w", "--width=width", Integer, "Image width") { |w| args[:w] = w }
  opts.on("-h", "--height=height", Integer, "Image height") { |h| args[:h] = h }
  opts.on("-s", "--spp=spp", Integer, "Samples per pixel") { |s| args[:spp] = s }
  opts.on("-o", "--output=filename", String, "Output filename") { |o| args[:filename] = o }
  opts.on("-p", "--[no-]progressive-save", "Save file while rendering") { |p| args[:prog_save] = p }
end.parse!
FILENAME = args[:filename]
PROGRESSIVE_SAVING = args[:prog_save]

# Begin rendering
start_time = Time.now
puts "Rendering #{args[:w]}x#{args[:h]}"
save_image(render(args[:w], args[:h], args[:spp]), FILENAME)
puts "Render completed in %.2f seconds" % (Time.now - start_time)