# Clear existing data
puts 'Clearing existing data...'
# Clear join table first to avoid foreign key constraint errors
ActiveRecord::Base.connection.execute("DELETE FROM acts_gigs")
[Gig, Act, Venue].each(&:delete_all)

# Create Venues
puts 'Creating venues...'
venues = {
  classic: Venue.create!(
    name: 'The Classic',
    address: '321 Queen Street',
    city: 'Auckland',
    country: 'New Zealand',
    latitude: -36.8485,
    longitude: 174.7633,
    capacity: 200,
    description: 'Auckland\'s premier comedy club since 1988',
    external_ids: { 'ticketmaster': 'ven_classic_akl' },
    images: {
      'standard': 'https://images.unsplash.com/photo-1603739903239-8b6e64c3b185?w=800&q=80',
      'large': 'https://images.unsplash.com/photo-1603739903239-8b6e64c3b185?w=1200&q=80',
      'medium': 'https://images.unsplash.com/photo-1603739903239-8b6e64c3b185?w=600&q=80',
      'square': 'https://images.unsplash.com/photo-1603739903239-8b6e64c3b185?w=400&h=400&fit=crop&q=80'
    }
  ),
  
  fringe: Venue.create!(
    name: 'The Fringe Bar',
    address: '26 Allen Street',
    city: 'Wellington',
    country: 'New Zealand',
    latitude: -41.2925,
    longitude: 174.7730,
    capacity: 120,
    description: 'Wellington\'s home of alternative comedy',
    external_ids: { 'ticketmaster': 'ven_fringe_wlg' },
    images: {
      'standard': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=80',
      'large': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=1200&q=80',
      'medium': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      'square': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400&h=400&fit=crop&q=80'
    }
  ),

  basement: Venue.create!(
    name: 'The Basement Theatre',
    address: 'Lower Greys Avenue',
    city: 'Auckland',
    country: 'New Zealand',
    latitude: -36.8506,
    longitude: 174.7645,
    capacity: 150,
    description: 'Underground comedy venue in the heart of the city',
    external_ids: { 'ticketmaster': 'ven_basement_akl' },
    images: {
      'standard': 'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=800&q=80',
      'large': 'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=1200&q=80',
      'medium': 'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=600&q=80',
      'square': 'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=400&h=400&fit=crop&q=80'
    }
  )
}

# Create Acts
puts 'Creating acts...'
acts = {
  rose: Act.create!(
    name: 'Rose Matafeo',
    description: 'Award-winning comedian from Auckland',
    social_links: {
      'twitter': '@Rose_Matafeo',
      'instagram': '@rose_matafeo'
    },
    external_ids: { 'ticketmaster': 'act_rose_matafeo' },
    images: {
      'standard': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=800&q=80',
      'large': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=1200&q=80',
      'medium': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=600&q=80',
      'square': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&h=400&fit=crop&q=80'
    }
  ),

  rhys: Act.create!(
    name: 'Rhys Darby',
    description: 'Actor and comedian known for Flight of the Conchords',
    social_links: {
      'twitter': '@rhysdarby',
      'instagram': '@rhysdarby'
    },
    external_ids: { 'ticketmaster': 'act_rhys_darby' },
    images: {
      'standard': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=80',
      'large': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=1200&q=80',
      'medium': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600&q=80',
      'square': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop&q=80'
    }
  ),

  guy: Act.create!(
    name: 'Guy Montgomery',
    description: 'Comedian and podcast host',
    social_links: {
      'twitter': '@guy_montgomery',
      'instagram': '@guy_montgomery'
    },
    external_ids: { 'ticketmaster': 'act_guy_montgomery' },
    images: {
      'standard': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=80',
      'large': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=1200&q=80',
      'medium': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&q=80',
      'square': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop&q=80'
    }
  )
}

# Create Gigs
puts 'Creating gigs...'

# Future gigs
gigs = {
  rose_classic: Gig.create!(
    name: 'Rose Matafeo: Honey Baby',
    start_time: 1.week.from_now.change(hour: 20),
    end_time: 1.week.from_now.change(hour: 21, min: 30),
    description: 'Brand new hour of comedy from Rose Matafeo',
    ticket_url: 'https://ticketmaster.example.com/rose-classic',
    status: 'scheduled',
    venue: venues[:classic],
    external_ids: { 'ticketmaster': 'gig_rose_classic_2025' }
  ),

  rhys_basement: Gig.create!(
    name: 'Rhys Darby: Mystic Time Bird',
    start_time: 2.weeks.from_now.change(hour: 19, min: 30),
    end_time: 2.weeks.from_now.change(hour: 21),
    description: 'Rhys Darby returns with a new mystical adventure',
    ticket_url: 'https://ticketmaster.example.com/rhys-basement',
    status: 'scheduled',
    venue: venues[:basement],
    external_ids: { 'ticketmaster': 'gig_rhys_basement_2025' }
  ),

  guy_fringe: Gig.create!(
    name: 'Guy Montgomery: Let Me Finish',
    start_time: 3.days.from_now.change(hour: 20),
    end_time: 3.days.from_now.change(hour: 21, min: 30),
    description: 'All new hour from Guy Montgomery',
    ticket_url: 'https://ticketmaster.example.com/guy-fringe',
    status: 'scheduled',
    venue: venues[:fringe],
    external_ids: { 'ticketmaster': 'gig_guy_fringe_2025' }
  )
}

# Associate acts with gigs
puts 'Creating act-gig associations...'
gigs[:rose_classic].acts << acts[:rose]
gigs[:rhys_basement].acts << acts[:rhys]
gigs[:guy_fringe].acts << acts[:guy]

puts 'Seed data created successfully!'
